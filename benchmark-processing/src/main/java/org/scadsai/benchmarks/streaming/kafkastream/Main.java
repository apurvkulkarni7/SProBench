package org.scadsai.benchmarks.streaming.kafkastream;

import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.KeyValue;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.KStream;
//import org.apache.kafka.streams.kstream.KStreamBuilder;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.scadsai.benchmarks.streaming.flink.utils.MetricLoggerMap;
import org.scadsai.benchmarks.streaming.kafkastream.sinks.SinkMain;
//import org.scadsai.benchmarks.streaming.kafka.sources.SourceMain;
//import org.scadsai.benchmarks.streaming.kafka.utils.MetricLoggerMap;
//import org.scadsai.benchmarks.streaming.kafkastream.OptionsGenerator;
import org.scadsai.benchmarks.streaming.kafkastream.Transformations;
import org.scadsai.benchmarks.streaming.utils.ConfigLoader.BenchmarkConfig;
import org.scadsai.benchmarks.streaming.utils.SensorReading;

import java.util.Properties;

import static org.scadsai.benchmarks.streaming.utils.Tools.roundOfThree;

public class Main {

    public static final Logger MAIN_LOGGER = LogManager.getLogger(Main.class);

    public static void main(String[] args) {
        OptionsGenerator options = new OptionsGenerator(args);
        BenchmarkConfig config = options.getConfig();
        Properties properties = options.getProperties();

        StreamsBuilder builder = new StreamsBuilder();

        KStream<String, String> sourceStream = builder.stream(config.getKafka().getSourceTopicNames());

        // Process the stream based on the processing type
        processStream(sourceStream, properties, config);

        // Create a Kafka Streams instance
        KafkaStreams streams = new KafkaStreams(builder.build(), properties);

        // Start the Kafka Streams instance
        streams.start();
    }

    private static void processStream(KStream<String, String> sourceStream, Properties properties, BenchmarkConfig config) {
        String processingType = config.getStreamProcessor().getProcessingType();

        if (processingType.equals("P0")) {
            sourceStream
                    .mapValues(values -> values + "," + System.currentTimeMillis())
                    .to(config.getKafka().getSinkTopicNames().get(0).toString());
        } else {
            Transformations transformations = new Transformations(config);

            KStream<String, SensorReading> parsedStream = sourceStream.mapValues(transformations::parseInput);

            if (processingType.equals("P1")) {
                KStream<String, SensorReading> mappedStream = parsedStream
                        .mapValues(transformations::TemperatureConvertorDetector)
                        .mapValues(transformations::MetricLoggerMap);
                mappedStream
                        .mapValues(input -> input.toString())
                        .to("eventsKafka");
                //.to(config.getKafka().getSinkTopicNames().get(0).toString());
            }
        }
    }

}