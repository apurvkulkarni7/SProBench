//
// Source code recreated from a .class file by IntelliJ IDEA
// (powered by FernFlower decompiler)
//

package org.scadsai.benchmarks.streaming.flink.jobs;

import org.apache.commons.cli.CommandLine;
import org.apache.flink.api.java.tuple.Tuple3;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.scadsai.benchmarks.streaming.flink.sinks.sinkMain;
import org.scadsai.benchmarks.streaming.flink.sources.sourceMain;
import org.scadsai.benchmarks.streaming.flink.utils.MetricLoggerMap;
import org.scadsai.benchmarks.streaming.flink.utils.OptionsGenerator;
import org.scadsai.benchmarks.streaming.flink.utils.SetupStreamExecEnv;
import org.scadsai.benchmarks.streaming.flink.utils.Transformations;

public class StreamProcessingMain {
    public static final Logger MainLogger = LogManager.getLogger("main");

    public StreamProcessingMain() {
    }

    public static void main(String[] args) {
        CommandLine opt = (new OptionsGenerator(args)).build();
        StreamExecutionEnvironment env = (new SetupStreamExecEnv(opt)).build();
        DataStream<String> sourceStream = sourceMain.fromSource(env, opt);
        if (opt.getOptionValue("processing-type").equals("P0")) {
            sinkMain.mySinkTo(
                    sourceStream.map(new MetricLoggerMap<>("events_out_p0", opt.getOptionValue("processing-type"))),
                    opt,
                    opt.getOptionValue("sink-kafka-topic")
            );
        } else {
            DataStream<Tuple3<Long, String, Double>> streamParsed = Transformations.inputEventParser(sourceStream);
            if (opt.getOptionValue("processing-type").equals("P1")) {
                sinkMain.mySinkTo(
                        streamParsed
                                .map(new MetricLoggerMap("events_out_p1")),
                        opt, opt.getOptionValue("sink-kafka-topic")
                );
            } else if (opt.getOptionValue("processing-type").equals("P2")) {
                sinkMain.mySinkTo(
                        streamParsed
                                .map(new Transformations.TemperatureUnitConvertor())
                                .map(new MetricLoggerMap("events_out_p2")),
                        opt, opt.getOptionValue("sink-kafka-topic")
                );
            }
        }

        try {
            env.execute();
        } catch (Exception var5) {
            throw new RuntimeException(var5);
        }
    }
}
