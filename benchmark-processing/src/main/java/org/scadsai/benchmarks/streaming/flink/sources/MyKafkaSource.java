package org.scadsai.benchmarks.streaming.flink.sources;

import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;

import java.util.Arrays;

public class MyKafkaSource {

    private final String bootstrapServer;
    private final String kafkaTopic;
    private final String groupId;

    public MyKafkaSource(String bootstrapServer, String kafkaTopic, String groupId) {
        this.bootstrapServer = bootstrapServer;
        this.kafkaTopic = kafkaTopic;
        this.groupId = groupId;
    }

    public KafkaSource build() {
        return KafkaSource
                .<String>builder()
                .setBootstrapServers(this.bootstrapServer)
                .setTopics(Arrays.asList(this.kafkaTopic.split(",")))
                .setGroupId(this.groupId)
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setValueOnlyDeserializer(new SimpleStringSchema())
                .build();
    }
}
