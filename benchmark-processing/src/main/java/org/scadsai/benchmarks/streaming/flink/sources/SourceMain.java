//
// Source code recreated from a .class file by IntelliJ IDEA
// (powered by FernFlower decompiler)
//

package org.scadsai.benchmarks.streaming.flink.sources;

import org.apache.commons.cli.CommandLine;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.typeinfo.BasicTypeInfo;
import org.apache.flink.api.java.io.TextInputFormat;
import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.source.FileProcessingMode;
import org.scadsai.benchmarks.streaming.flink.Main;

public class SourceMain {
    public SourceMain() {
    }

    public static DataStream<String> fromSource(StreamExecutionEnvironment env, CommandLine opt) {
        String path;
        if (opt.getOptionValue("source-type").equals("kafka")) {
            path = opt.getOptionValue("source-kafka-topic", "logs");
            String kafkaBootstrapServer = opt.getOptionValue("source-bootstrap-server", "localhost:9092");
            String kafkaGroupId = opt.getOptionValue("source-group-id", "logs-group");
            Main.MAIN_LOGGER.info("Reading data from Kafka-topic:{}, Bootstrap-server:{}", path, kafkaBootstrapServer);
            return env.fromSource((new MyKafkaSource(kafkaBootstrapServer, path, kafkaGroupId)).build(), WatermarkStrategy.noWatermarks(), "Kafka source").name("source");
        } else if (opt.getOptionValue("source-type").equals("file")) {
            Main.MAIN_LOGGER.info("Reading data from: {}", opt.getOptionValue("srcFile"));
            path = opt.getOptionValue("source-file");
            TextInputFormat inputFormat = new TextInputFormat(new Path(path));
            inputFormat.setCharsetName("UTF-8");
            return env.readFile(inputFormat, path, FileProcessingMode.PROCESS_CONTINUOUSLY, 1L, BasicTypeInfo.STRING_TYPE_INFO);
        } else {
            Main.MAIN_LOGGER.error("Invalid/Unimplemented source selected");
            System.exit(0);
            return null;
        }
    }
}
