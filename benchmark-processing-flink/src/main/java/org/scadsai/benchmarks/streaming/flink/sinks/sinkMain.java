//
// Source code recreated from a .class file by IntelliJ IDEA
// (powered by FernFlower decompiler)
//

package org.scadsai.benchmarks.streaming.flink.sinks;

import org.apache.commons.cli.CommandLine;
import org.apache.flink.api.common.serialization.SimpleStringEncoder;
import org.apache.flink.configuration.MemorySize;
import org.apache.flink.configuration.MemorySize.MemoryUnit;
import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.datastream.SingleOutputStreamOperator;
import org.apache.flink.streaming.api.functions.sink.filesystem.StreamingFileSink;
import org.apache.flink.streaming.api.functions.sink.filesystem.rollingpolicies.DefaultRollingPolicy;
import org.scadsai.benchmarks.streaming.flink.jobs.StreamProcessingMain;
import org.scadsai.benchmarks.streaming.flink.utils.Tools;

import java.io.File;
import java.time.Duration;

public class sinkMain {
    public sinkMain() {
    }

    public static void mySinkTo(DataStream inputStream, CommandLine opt, String identifier) {
        SingleOutputStreamOperator inputStreamString = inputStream.map( i -> i.toString() + "," + System.currentTimeMillis());
        if (opt.getOptionValue("sink-type").equals("kafka")) {
            String kafkaBootstrapServer = opt.getOptionValue("sink-bootstrap-server", "localhost:9092");
            StreamProcessingMain.MainLogger.info("Writing output to Kafka-topic:{}, Kafka-Bootstrap-Server:{}", identifier, kafkaBootstrapServer);
            inputStreamString.sinkTo((new MyKafkaSink(kafkaBootstrapServer, identifier)).build()).name("sink");
        } else if (opt.getOptionValue("sink-type").equals("stdout")) {
            inputStreamString.print().name(identifier);
        } else if (opt.getOptionValue("sink-type").equals("filesystem")) {
            Path outFile = new Path("./out/" + identifier);
            Tools.deleteDirectory(new File(outFile.toString()));
            StreamProcessingMain.MainLogger.info("Writing output to: {}", outFile.getPath());
            StreamingFileSink<String> sink = ((StreamingFileSink.DefaultRowFormatBuilder) StreamingFileSink.forRowFormat(outFile, new SimpleStringEncoder("UTF-8")).withRollingPolicy(DefaultRollingPolicy.builder().withRolloverInterval(Duration.ofSeconds(Long.parseLong(opt.getOptionValue("runtime", "300")))).withMaxPartSize(MemorySize.parse("2", MemoryUnit.GIGA_BYTES)).build())).build();
            inputStreamString.addSink(sink);
        }

    }
}
