package org.util;

import java.time.Duration;
import java.util.Arrays;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;

import static org.util.CliParamGenerator.mainLogger;

public class KafkaEventLatencyCalculator {
    static Properties properties = new Properties();
    static KafkaConsumer<String, String> kafkaConsumer;
    static Pattern pattern;

    public KafkaEventLatencyCalculator(String bootstrapServer, String topic, String groupID, String loggingIntervalMs, String regexPattern){

        properties = setProperty(bootstrapServer, topic, groupID, loggingIntervalMs);

        // Create the Kafka consumer
        kafkaConsumer = new KafkaConsumer<>(properties);
        kafkaConsumer.subscribe(Arrays.asList(properties.getProperty("topic").split(",")));
        pattern = Pattern.compile(regexPattern);

    }
    public KafkaEventLatencyCalculator(String bootstrapServer, String topic, String groupID, String loggingIntervalMs){
        properties = setProperty(bootstrapServer, topic, groupID, loggingIntervalMs);
        // Create the Kafka consumer
        kafkaConsumer = new KafkaConsumer<>(properties);
        kafkaConsumer.subscribe(Arrays.asList(properties.getProperty("topic").split(",")));
    }

    public static Properties setProperty(String bootstrapServer, String topic, String groupID, String loggingIntervalMs) {

        // Set the Kafka consumer properties
        properties.setProperty(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        properties.setProperty(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        properties.setProperty(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        //properties.setProperty(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "latest");
//        properties.setProperty(ConsumerConfig.GROUP_ID_CONFIG, "kafka-sink-throughput-and-latency-calculator");
//        properties.setProperty("topic","ad-events-sink");
//        properties.setProperty("loggingInterval","10");
        properties.setProperty(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServer);
        properties.setProperty(ConsumerConfig.GROUP_ID_CONFIG, groupID);
        properties.setProperty("topic",topic);
        properties.setProperty("loggingIntervalMs",loggingIntervalMs);
        return properties;
    }

    public static String getKafkaEventLatency(){
        ConsumerRecords<String, String> records = kafkaConsumer.poll(Duration.ofMillis(Long.parseLong(properties.getProperty("loggingIntervalMs"))));
        long latencyTmp = 0;
        //long latencyMax = 0;
        for (ConsumerRecord record : records) {
            //long incomingTimestamp = Long.parseLong(extractTimestamp(record.value().toString()));
            long incomingTimestamp = Long.parseLong(record.value().toString().split(",")[0]);
            long kafkaTimestamp = record.timestamp();
            // Calculate the latency
            latencyTmp += (kafkaTimestamp - incomingTimestamp);
            //mainLogger.info("{}",record.value());
            //mainLogger.info("{} - {} = {}",kafkaTimestamp,incomingTimestamp,kafkaTimestamp - incomingTimestamp);
        }

        String latencyAveraged = "";
        if (records.count() != 0) {
            latencyAveraged = String.valueOf((double) latencyTmp / (double) records.count());
        }
        return latencyAveraged;
    }

    private static String extractTimestamp(String inputString) {
        // Use Matcher to perform the extraction
        Matcher matcher = pattern.matcher(inputString);

        // Find the first match
        if (matcher.find()) {
            return matcher.group(1); // Group 1 corresponds to the timestamp
        } else {
            mainLogger.error(inputString);
            return "No timestamp found";
        }
    }
}
