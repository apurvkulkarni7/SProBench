package org.scadsai.benchmarks.streaming.sparkstrucstreaming;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.spark.api.java.function.FilterFunction;
import org.apache.spark.api.java.function.MapFunction;
import org.apache.spark.sql.*;
import org.apache.spark.sql.streaming.OutputMode;
import org.apache.spark.sql.streaming.StreamingQuery;
import org.apache.spark.sql.streaming.StreamingQueryException;
import org.apache.spark.sql.streaming.StreamingQueryListener;
import org.scadsai.benchmarks.streaming.kafkastream.OptionsGenerator;
import org.scadsai.benchmarks.streaming.utils.ConfigLoader.BenchmarkConfig;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorIdStats;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorReading;
import org.apache.spark.sql.types.DataTypes;

import java.util.Objects;
import java.util.Properties;
import java.util.concurrent.TimeoutException;

import static org.apache.spark.sql.functions.*;

public class MainSparkStrucStreaming {

    public static final Logger MAIN_LOGGER = LogManager.getLogger("main");
    public static final Logger METRIC_LOGGER = LogManager.getLogger("metric");

    public static void main(String[] args) {
        MAIN_LOGGER.info("Starting streaming process");

        OptionsGenerator options = new OptionsGenerator(args);
        BenchmarkConfig config = options.getConfig();
        Properties properties = options.getProperties();

        // Initialize Spark Session
        SparkSession spark = SparkSession.builder()
                .appName("SProBench_SparkStucStream")
                .master("local[*]")
                .getOrCreate();

        spark.sparkContext().setLogLevel("WARN");

        // Read from Kafka
        Dataset<Row> sourceStream = spark
                .readStream()
                .format("kafka")
                .option("kafka.bootstrap.servers", config.getKafka().getSourceBootstrapServer())
                .option("subscribe", config.getKafka().getSourceTopicNames())
                .option("startingOffsets", "latest")
                .option("failOnDataLoss", "false")
                .load()
                .selectExpr("CAST(value AS STRING)");
        Dataset<String> processedBatch = processStream(sourceStream, config);

        // Write the data stream back to Kafka
        try {
            StreamingQuery query = processedBatch
                    .writeStream()
                    .format("kafka")
                    .option("kafka.bootstrap.servers", config.getKafka().getSinkBootstrapServer())
                    .option("topic", config.getKafka().getSinkTopicNames())
                    .outputMode(OutputMode.Append()) // Only new data is written
                    .option("checkpointLocation", config.getTmpDir() + "/kafka-checkpoint")
                    .start();
        } catch (TimeoutException e) {
            throw new RuntimeException(e);
        }

        // Add listener for error handling
        spark.streams().addListener(new StreamingQueryListener() {
            @Override
            public void onQueryStarted(QueryStartedEvent event) {
                MAIN_LOGGER.info("Query started: " + event.id());
            }

            @Override
            public void onQueryProgress(QueryProgressEvent event) {
                // Query is making progress
            }

            @Override
            public void onQueryTerminated(QueryTerminatedEvent event) {
                if (event.exception() != null) {
                    MAIN_LOGGER.error("Query terminated with error: " + event.exception());
                }
            }
        });

        // Wait for the streaming to finish
        try {
            spark.streams().awaitAnyTermination();
        } catch (StreamingQueryException e) {
            MAIN_LOGGER.error("Error at termination");
            throw new RuntimeException(e);
        }
    }

    private static Dataset<String> processStream(Dataset<Row> sourceStream, BenchmarkConfig config) {
        String processingType = config.getStreamProcessor().getProcessingType();

        Dataset<String> result = null;

        // pass through
        if (processingType.equals("P0")) {
            // P0: Pass-through with timestamp
            result = sourceStream.select(
                            split(col("value"), ",").getItem(0).as("timestamp"),
                            split(col("value"), ",").getItem(1).as("sensorId"),
                            split(col("value"), ",").getItem(2).as("value")
                    ).withColumn("ingestTimestamp", current_timestamp())
                    .withColumn("ingestTimestamp",
                            unix_timestamp(col("ingestTimestamp"))
                                    .multiply(1000)
                                    .plus(expr("cast(date_format(ingestTimestamp, 'SSS') as long)"))
                                    .cast("long")
                    )
                    .selectExpr(
                            "CAST(ingestTimestamp AS STRING) AS key", // Use ingest timestamp as key (optional)
                            "CAST(concat_ws(',', timestamp, sensorId, value, ingestTimestamp) AS STRING) AS value"
                    ).toJSON();
        } else {
            // Parse input
            Dataset<SensorReading> parsedStream = sourceStream
                    .map(
                            (MapFunction<Row, SensorReading>) row -> {
                                String[] parts = row.getString(0).split(",");
                                if (parts.length == 3) {
                                    long timestamp = Long.parseLong(parts[0]);
                                    String sensorId = parts[1];
                                    double value = Double.parseDouble(parts[2]);
                                    return new SensorReading(timestamp, sensorId, value);
                                } else {
                                    return null;
                                }
                            },
                            Encoders.javaSerialization(SensorReading.class)
                    )
                    .filter((FilterFunction<SensorReading>) Objects::nonNull);
            if (processingType.equals("P1")) {
                result = parsedStream
                        .map(
                                (MapFunction<SensorReading, SensorReading>) row -> {
                                    row.setTemperature((row.getTemperature() * 9 / 5) + 32);
                                    row.setAboveThreashold(row.getTemperature() > 70);
                                    return row;
                                },
                                Encoders.javaSerialization(SensorReading.class)
                        )
                        .toJSON();
            } else if (processingType.equals("P2")) {
                result = parsedStream
                        .withColumn(
                                "eventTime", (col("timestamp").cast(DataTypes.LongType).$div(1000))
                                        .cast(DataTypes.TimestampType)
                        )
                        .withWatermark("eventTime", "100 milliseconds")
                        .groupBy(
                                col("sensordId"),
                                window(
                                        parsedStream.col("eventTime"),
                                        config.getStreamProcessor().getWindowLengthMs() + " milliseconds",
                                        config.getStreamProcessor().getWindowAdvanceMs() + " milliseconds"
                                )
                        )
                        .agg(
                                first("sensorId").as("sensorId"),
                                min("temperature").as("min"),
                                max("temperature").as("max"),
                                sum("temperature").as("sum"),
                                avg("temperature").as("avg"),
                                count("timestamp").as("count"),
                                max("timestamp").as("lastTimestamp")
                        )
                        .withColumn("windowLength", lit(config.getStreamProcessor().getWindowLengthMs()))
                        .withColumn("throughput", ( // Throughput: events per second
                                col("count")
                                        .cast(DataTypes.LongType)
                                        .multiply(1000L)
                                        .divide(lit(config.getStreamProcessor().getWindowLengthMs())).cast(DataTypes.LongType)
                                        .cast(DataTypes.LongType)
                        ))
                        .withColumn("latency", (
                                unix_timestamp(col("window.end"))
                                        .cast(DataTypes.LongType)
                                        .multiply(1000L)
                                        .minus(col("lastTimestamp"))
                        ))
                        .select(
                                col("sensorId"),
                                col("temperatureMin"),
                                col("temperatureMax"),
                                col("temperatureAvg"),
                                col("throughput"),
                                col("latency")
                        ).toJSON();
            }
        }
        return result;
    }

}