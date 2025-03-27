package org.scadsai.benchmarks.streaming.kafkastream;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.scadsai.benchmarks.streaming.utils.ConfigLoader.BenchmarkConfig;
import org.scadsai.benchmarks.streaming.utils.SensorReading;
import org.scadsai.benchmarks.streaming.kafkastream.Main;

import static org.scadsai.benchmarks.streaming.utils.Tools.roundOfThree;

public class Transformations {
    public static final Logger metricLogger = LogManager.getLogger("metric");
    private static long timeOne =System.currentTimeMillis();
    private static long event_count=0L;
    public BenchmarkConfig benchmarkConfig;
    public Transformations(BenchmarkConfig benchmarkConfig) {
        this.benchmarkConfig =  benchmarkConfig;
        metricLogger.info("Latency (ms), Throughput (events/second)");
    }
    public SensorReading parseInput(String input) {
        try {
            String[] data = input.toString().split(",");
            return new SensorReading(Long.parseLong(data[0]), data[1], Double.parseDouble(data[2]));
        } catch (Exception e) {
            return new SensorReading(0, "", 0);
        }
    }

    public SensorReading TemperatureConvertorDetector (SensorReading input) {
        input.aboveThreashold = input.temperature > 70;
        input.temperature = roundOfThree((input.temperature * 9 / 5) + 32);
        return input;
    }

    public SensorReading MetricLoggerMap(SensorReading input) {
        long curr_time = System.currentTimeMillis();
        if (curr_time - timeOne > (benchmarkConfig.getMetricLoggingIntervalSec()* 1000L)) {
            long throughput = event_count / benchmarkConfig.getMetricLoggingIntervalSec();
            long latency = System.currentTimeMillis() - input.timestamp;
            metricLogger.info("{},{}", throughput,latency);
            timeOne = curr_time;
        } else {
            event_count++;
        }
        return input;
    }
}
