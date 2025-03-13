package org.scadsai.benchmarks.streaming.generator.sink;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerRecord;

import java.util.Properties;

public class MyKafkaProducer {

    public String kafkaTopic;
    public Producer producer;

    public MyKafkaProducer(Properties producerProperties) {
        producerProperties.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        producerProperties.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        this.producer = new KafkaProducer<String, String>(producerProperties);
        this.kafkaTopic = producerProperties.getProperty("topic");
    }

    public void send(String input) {
        producer.send(new ProducerRecord<>(this.kafkaTopic, input));
    }

    // If used this, there is no gaurantee that 2 different sensor ID events will go to different partition.
    public void send(String key, String val) {
        producer.send(new ProducerRecord<>(this.kafkaTopic, key,val));
    }
    public void send(Integer partition, String key, String input) {
        producer.send(new ProducerRecord<>(this.kafkaTopic, partition, key, input));
        // long generateTime = Long.valueOf(input.split(",")[0]);
        // producer.send(
        //     new ProducerRecord<>(this.kafkaTopic, partition, key, input),
        //     (metadata, exception) -> {
        //         if (exception == null) {
        //             long writeTime = System.currentTimeMillis();
        //             long latency = writeTime - generateTime;
        //             System.out.println("Message latency: " + latency + " ms");
        //         }
        //     }
        // );
    }

    public void close() {
        producer.close();
    }
}
