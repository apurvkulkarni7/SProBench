package org.scadsai.benchmarks.streaming.flink.sinks;

import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.base.DeliveryGuarantee;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaProducer;

public class MyKafkaSink {

    private final String bootstrapServer;
    private final String kafkaTopic;

    public MyKafkaSink(String bootstrapServer, String kafkaTopic) {
        this.bootstrapServer = bootstrapServer;
        this.kafkaTopic = kafkaTopic;
    }

    // Sinks
    public KafkaSink build() {
        return KafkaSink
                .<String>builder()
                .setBootstrapServers(bootstrapServer)
                .setDeliveryGuarantee(DeliveryGuarantee.EXACTLY_ONCE)
                .setProperty("batch.size","500000")
                .setProperty("linger.ms","1")
                .setProperty("compression.type","lz4")
                .setRecordSerializer(
                        KafkaRecordSerializationSchema
                                .builder()
                                .setTopic(kafkaTopic)
                                .setValueSerializationSchema(new SimpleStringSchema())
                                .setKeySerializationSchema(new SimpleStringSchema())
                                .build()
                )
                .build();
    }
}
