package org.scadsai.benchmarks.streaming.sparkstrucstreaming;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.spark.api.java.function.MapFunction;
import org.apache.spark.sql.*;
import org.apache.spark.sql.streaming.OutputMode;
import org.apache.spark.sql.streaming.StreamingQuery;
import org.apache.spark.sql.streaming.StreamingQueryException;
import org.apache.spark.sql.streaming.StreamingQueryListener;
import org.scadsai.benchmarks.streaming.kafkastream.OptionsGenerator;
import org.scadsai.benchmarks.streaming.utils.ConfigLoader.BenchmarkConfig;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorReading;
import org.apache.spark.sql.types.DataTypes;

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
        Transformations transformations = new Transformations(config);
        Dataset<String> result = null;
        if (processingType.equals("P0")) {
            result = transformations.applyP0(sourceStream);
        } else {
            Dataset<SensorReading> parsedStream = transformations.parseToSensorReading(sourceStream);
            if (processingType.equals("P1")) {
                result = transformations.applyP1(parsedStream);
            } else if (processingType.equals("P2")) {
                result = transformations.applyP2(parsedStream);
            }
        }
        return result;
    }

}