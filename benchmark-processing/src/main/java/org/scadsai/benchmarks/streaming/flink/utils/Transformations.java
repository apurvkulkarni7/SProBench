package org.scadsai.benchmarks.streaming.flink.utils;

import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.functions.RichMapFunction;
import org.apache.flink.api.common.state.ValueState;
import org.apache.flink.api.common.state.ValueStateDescriptor;
import org.apache.flink.api.common.typeinfo.Types;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.api.java.tuple.Tuple3;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.functions.windowing.AllWindowFunction;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.util.Collector;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorReading;

import static org.scadsai.benchmarks.streaming.utils.Tools.roundOfThree;

public class Transformations {

    public static final Logger Logger = LogManager.getLogger("throughput");

    public Transformations() {
    }


    public static DataStream<SensorReading> inputEventParser(DataStream<String> inputStream) {
        return inputStream.map(new MapFunction<String, SensorReading>() {
            @Override
            public SensorReading map(String input) throws Exception {
                String[] elements = input.split(",");
                return new SensorReading(Long.parseLong(elements[0]), elements[1], Double.parseDouble(elements[2]));
            }
        });
    }

    public static class TemperatureUnitConvertor implements MapFunction<Tuple3<Long, String, Double>, Tuple3<Long, String, Double>> {
        @Override
        public Tuple3<Long, String, Double> map(Tuple3<Long, String, Double> inputStream) throws Exception {
            return new Tuple3<>(inputStream.f0, inputStream.f1, roundOfThree((inputStream.f2 * 9 / 5) + 32));
        }
    }

    public static class TemperatureConvertorDetector implements MapFunction<SensorReading, SensorReading> {
        @Override
        public SensorReading map(SensorReading inputStream) throws Exception {
            inputStream.setAboveThreshold(inputStream.getTemperature() > 70);
            inputStream.setTemperature(roundOfThree((inputStream.getTemperature() * 9 / 5) + 32));
            return inputStream;
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


    public static class MovingAverageFlatMap extends RichMapFunction<
            SensorReading, // Input: (timestamp, sensor_id, temperature, boolean)
            SensorReading // Output: (timestamp, sensor_id, temperature, boolean, moving_avg)
            > {

        private transient ValueState<Tuple2<Double, Integer>> sumCountState;

        @Override
        public void open(Configuration parameters) {
            ValueStateDescriptor<Tuple2<Double, Integer>> descriptor =
                    new ValueStateDescriptor<>(
                            "sumCountState", Types.TUPLE(Types.DOUBLE, Types.INT)
                    );
            sumCountState = getRuntimeContext().getState(descriptor);
        }

        @Override
        public SensorReading map(SensorReading input) throws Exception {
            // Get the current state
            Tuple2<Double, Integer> current = sumCountState.value();
            if (current == null) {
                current = Tuple2.of(0.0, 0);
            }

            // Update sum and count
            current.f0 += input.getTemperature(); // Temperature
            current.f1 += 1;

            // Compute moving average
            //input.average = roundOfThree(current.f0 / current.f1);
            sumCountState.update(current);
            return input;
        }
    }
}


//public class MovingAverageFlatMap extends RichFlatMapFunction<Tuple4, Tuple5> {
//
//    private transient ValueState<Tuple2<Double, Integer>> sumCountState;
//
//    @Override
//    public void open(Configuration parameters) {
//        ValueStateDescriptor<Tuple2<Double, Integer>> descriptor =
//                new ValueStateDescriptor<>("sumCountState", Types.TUPLE(Types.DOUBLE, Types.INT));
//        sumCountState = getRuntimeContext().getState(descriptor);
//    }
//
//    @Override
//    public void flatMap(Tuple4<Long, String, Double, Boolean> input, Collector<Tuple5> out) throws Exception {
//        Tuple2<Double, Integer> current = sumCountState.value();
//        if (current == null) {
//            current = Tuple2.of(0.0, 0);
//        }
//
//        current.f0 += input.f2;
//        current.f1 += 1;
//        double average = current.f0 / current.f1;
//
//        sumCountState.update(current);
//        out.collect(new Tuple5(input.f0,input.f1,input.f2,input.f3, average));
//    }
//}
