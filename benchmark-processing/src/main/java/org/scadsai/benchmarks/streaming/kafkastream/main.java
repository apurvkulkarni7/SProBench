package org.scadsai.benchmarks.streaming.kafkastream;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Produced;

import java.util.Properties;
import java.util.concurrent.CountDownLatch;

public class main {
    public static void main(String[] args) {
        // Set up the configuration properties
        Properties props = new Properties();
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "kafka-stream-processor");
        props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass());
        props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass());

        // Create the stream builder
        StreamsBuilder builder = new StreamsBuilder();

        // Define the stream: read from input-topic
        KStream<String, String> source = builder.stream("input-topic");

        // Process the stream (parse/transform data)
        KStream<String, String> processed = source.mapValues(value -> {
            // Example transformation: convert to uppercase
            // Replace this with your actual parsing/transformation logic
            return parseData(value);
        });

        // Send the processed data to output-topic
        processed.to("output-topic", Produced.with(Serdes.String(), Serdes.String()));

        // Build the topology
        KafkaStreams streams = new KafkaStreams(builder.build(), props);

        // Set up clean shutdown
        final CountDownLatch latch = new CountDownLatch(1);
        Runtime.getRuntime().addShutdownHook(new Thread("streams-shutdown-hook") {
            @Override
            public void run() {
                streams.close();
                latch.countDown();
            }
        });

        try {
            streams.start();
            latch.await();
        } catch (Throwable e) {
            System.exit(1);
        }
        System.exit(0);
    }

    private static String parseData(String data) {
        // Implement your custom parsing logic here
        // This is just a simple example - replace with your actual parsing needs
        try {
            // Example: Split by comma and extract the second field
            String[] parts = data.split(",");
            if (parts.length > 1) {
                return parts[1].trim();
            } else {
                return data.toUpperCase();
            }
        } catch (Exception e) {
            System.err.println("Error parsing data: " + e.getMessage());
            return "ERROR_PARSING_" + data;
        }
    }
}