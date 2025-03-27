//
// Source code recreated from a .class file by IntelliJ IDEA
// (powered by FernFlower decompiler)
//

package org.scadsai.benchmarks.streaming.flink;

import org.apache.commons.cli.CommandLine;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.scadsai.benchmarks.streaming.flink.sinks.SinkMain;
import org.scadsai.benchmarks.streaming.flink.sources.SourceMain;
import org.scadsai.benchmarks.streaming.flink.utils.MetricLoggerMap;
import org.scadsai.benchmarks.streaming.utils.OptionsGenerator;
import org.scadsai.benchmarks.streaming.flink.utils.SetupStreamExecEnv;
import org.scadsai.benchmarks.streaming.flink.utils.Transformations;
import org.scadsai.benchmarks.streaming.utils.SensorReading;


public class Main {
    public static final Logger MAIN_LOGGER = LogManager.getLogger("main");

    public static void main(String[] args) {
        CommandLine opt = new OptionsGenerator(args).build();

        StreamExecutionEnvironment env = new SetupStreamExecEnv(opt).build();

        DataStream<String> sourceStream = SourceMain.fromSource(env, opt); //.rebalance();

        processStream(sourceStream, opt);

        try {
            env.execute();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static void processStream(DataStream<String> sourceStream, CommandLine options) {
        String processingType = options.getOptionValue("processing-type");

        if (processingType.equals("P0")) {
            // Process type P0
            DataStream<String> mappedStream = sourceStream
                    .map(new MetricLoggerMap<>("events_out_p0", processingType));
            SinkMain.mySinkTo(mappedStream, options, options.getOptionValue("sink-kafka-topic"));
        } else {
            // Parse the input events
            DataStream<SensorReading> parsedStream = Transformations.inputEventParser(sourceStream);

            if (processingType.equals("P1")) {
                // Process type P1
                DataStream<SensorReading> mappedStream = parsedStream
                        .map(new Transformations.TemperatureConvertorDetector())
                        .map(new MetricLoggerMap<>("events_out_p1"));
                // .keyBy(value -> value.sensorId)
                // .map(new Transformations.MovingAverageFlatMap())
                SinkMain.mySinkTo(mappedStream, options, options.getOptionValue("sink-kafka-topic"));
            }
        }
    }
}
