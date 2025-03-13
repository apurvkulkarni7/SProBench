package org.scadsai.benchmarks.streaming.flink.utils;

import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.api.java.tuple.Tuple3;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.functions.windowing.AllWindowFunction;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.util.Collector;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import static org.scadsai.benchmarks.streaming.flink.utils.Tools.roundOfThree;

public class Transformations {
    public static final Logger Logger = LogManager.getLogger("throughput");

    public Transformations() {
    }

    public static DataStream<Tuple3<Long, String, Double>> inputEventParser(DataStream<String> inputStream) {
        return inputStream.map(new MapFunction<String, Tuple3<Long, String, Double>>() {
            @Override
            public Tuple3<Long, String, Double> map(String input) throws Exception {
                String[] elements = input.split(",");
                return new Tuple3<>(Long.parseLong(elements[0]), elements[1], Double.parseDouble(elements[2]));
            }
        });
    }

    public static class TemperatureUnitConvertor implements MapFunction<Tuple3<Long, String, Double>, Tuple3<Long, String, Double>> {
        @Override
        public Tuple3<Long, String, Double> map(Tuple3<Long, String, Double> inputStream) throws Exception {
            return new Tuple3<>(inputStream.f0, inputStream.f1, roundOfThree((inputStream.f2 * 9 / 5) + 32));
        }
    }


    public static DataStream<Tuple2<Long, Double>> windowAverageAll(DataStream<Tuple3<Long, String, Double>> inputStream, long windowengthMs) {
        return inputStream
                .windowAll(TumblingProcessingTimeWindows.of(Time.milliseconds(windowengthMs)))
                .apply(new AllWindowFunction<Tuple3<Long, String, Double>, Tuple2<Long, Double>, TimeWindow>() {
                    @Override
                    public void apply(TimeWindow timeWindow, Iterable<Tuple3<Long, String, Double>> iterable, Collector<Tuple2<Long, Double>> collector) throws Exception {

                    }
                });
    }

}
