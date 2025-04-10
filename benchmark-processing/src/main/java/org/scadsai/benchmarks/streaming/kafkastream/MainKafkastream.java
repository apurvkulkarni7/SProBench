package org.scadsai.benchmarks.streaming.kafkastream;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.common.utils.Bytes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.*;
import org.apache.kafka.streams.state.WindowStore;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.scadsai.benchmarks.streaming.utils.ConfigLoader.BenchmarkConfig;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorIdStats;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorIdStatsSerde;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorReading;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorReadingSerde;

import java.time.Duration;
import java.util.Properties;

public class MainKafkastream {

    // Get the main logger
    public static final Logger MAIN_LOGGER = LogManager.getLogger("main");
    // Get the metrics logger
    public static final Logger METRIC_LOGGER = LogManager.getLogger("metric");


    public static void main(String[] args) {
        MAIN_LOGGER.info("Starting streaming process");

        OptionsGenerator options = new OptionsGenerator(args);
        BenchmarkConfig config = options.getConfig();
        Properties properties = options.getProperties();

        StreamsBuilder builder = new StreamsBuilder();

        KStream<String, String> sourceStream = builder.stream(config.getKafka().getSourceTopicNames());

        // Process the stream based on the processing type
        processStream(sourceStream, config);

        // Create a Kafka Streams instance
        KafkaStreams streams = new KafkaStreams(builder.build(), properties);

        // Start the Kafka Streams instance
        streams.start();
    }

    private static void processStream(KStream<String, String> sourceStream, BenchmarkConfig config) {
        String processingType = config.getStreamProcessor().getProcessingType();
        if (processingType.equals("P0")) {
            sourceStream
                    .mapValues(values -> values + "," + System.currentTimeMillis())
                    .to(config.getKafka().getSinkTopicNames());
        } else {
            Transformations transformations = new Transformations(config);

            KStream<String, SensorReading> parsedStream = sourceStream.mapValues(transformations::parseInput);
            String sinkTopics = config.getKafka().getSinkTopicNames();

            if (processingType.equals("P1")) {
                KStream<String, SensorReading> mappedStream = parsedStream
                        .mapValues(transformations::TemperatureConvertorDetector)
                        .mapValues(transformations::MetricLoggerMap);
                mappedStream
                        .mapValues(SensorReading::toString)
                        .to(config.getKafka().getSinkTopicNames());
            } else if (processingType.equals("P2")) {
                KTable<Windowed<String>, SensorIdStats> mappedStream = parsedStream
                        .groupBy(
                                (KeyValueMapper<String, SensorReading, String>) (key, value) -> value.getSensorId(),
                                Grouped.with(Serdes.String(), new SensorReadingSerde())
                        )
                        .windowedBy(
                                TimeWindows.ofSizeWithNoGrace(Duration.ofMillis(config.getStreamProcessor().getWindowLengthMs()))
                                        .advanceBy(Duration.ofMillis(config.getStreamProcessor().getWindowAdvanceMs()))
                        )
                        .aggregate(
                                () -> new SensorIdStats(),                                  // Initialize
                                (key, value, stats) -> {    // Assuming 'value' is of type SensorReading and 'key' is sensorId (String)
                                    stats.setSensorId(key);
                                    stats.update(key, value.getTimestamp(), value.getTemperature(), config.getStreamProcessor().getWindowLengthMs());
                                    return stats;
                                },
                                Materialized.<String, SensorIdStats, WindowStore<Bytes, byte[]>>as("sensor-stats-store")
                                        .withKeySerde(Serdes.String())  // Ensure key is String
                                        .withValueSerde(new SensorIdStatsSerde())  // Custom Serde for SensorIdStats
                        )
                        .suppress(Suppressed.untilWindowCloses(Suppressed.BufferConfig.unbounded()));
                mappedStream
                        .toStream()
                        .mapValues(transformations::MetricLoggerMap)
                        .mapValues(SensorIdStats::toString)
                        .to(config.getKafka().getSinkTopicNames());
            }
        }
    }

}