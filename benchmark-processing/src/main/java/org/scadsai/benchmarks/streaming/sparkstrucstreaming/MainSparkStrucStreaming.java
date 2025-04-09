package org.scadsai.benchmarks.streaming.sparkstrucstreaming;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.spark.api.java.function.FilterFunction;
import org.apache.spark.api.java.function.MapFunction;
import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Encoders;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.SparkSession;
import org.apache.spark.sql.streaming.OutputMode;
import org.apache.spark.sql.streaming.StreamingQuery;
import org.apache.spark.sql.streaming.StreamingQueryException;
import org.apache.spark.sql.streaming.StreamingQueryListener;
import org.scadsai.benchmarks.streaming.kafkastream.OptionsGenerator;
import org.scadsai.benchmarks.streaming.utils.ConfigLoader.BenchmarkConfig;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorReading;

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

        spark.sparkContext().setLogLevel("INFO");

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
                            split(col("value"), ",").getItem(0).as("timestamp_ms"),
                            split(col("value"), ",").getItem(1).as("sensor_id"),
                            split(col("value"), ",").getItem(2).as("value")
                    ).withColumn("ingest_timestamp", current_timestamp())
                    .withColumn("ingest_timestamp_ms",
                            unix_timestamp(col("ingest_timestamp"))
                                    .multiply(1000)
                                    .plus(expr("cast(date_format(ingest_timestamp, 'SSS') as long)"))
                                    .cast("long")
                    )
                    .selectExpr(
                            "CAST(ingest_timestamp AS STRING) AS key", // Use ingest timestamp as key (optional)
                            "CAST(concat_ws(',', timestamp_ms, sensor_id, value, ingest_timestamp_ms) AS STRING) AS value"
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
            }
//            else if (processingType.equals("P2")) {
//                result = parsedStream.map(
//                        (MapFunction<SensorReading, SensorIdStats>) row -> {
//
//                            return String.valueOf(row);
//                        },
//                        Encoders.javaSerialization(String.class));
//            }
        }
        return result;
    }

}