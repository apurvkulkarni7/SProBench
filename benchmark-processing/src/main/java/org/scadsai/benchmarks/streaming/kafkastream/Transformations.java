package org.scadsai.benchmarks.streaming.kafkastream;

import org.scadsai.benchmarks.streaming.utils.ConfigLoader.BenchmarkConfig;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorIdStats;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorReading;

import static org.scadsai.benchmarks.streaming.kafkastream.MainKafkastream.METRIC_LOGGER;
import static org.scadsai.benchmarks.streaming.utils.Tools.roundOfThree;

public class Transformations {

    private static long timeOne = System.currentTimeMillis();
    private static long event_count = 0L;
    public BenchmarkConfig benchmarkConfig;

    public Transformations(BenchmarkConfig benchmarkConfig) {
        this.benchmarkConfig = benchmarkConfig;
        METRIC_LOGGER.info("Latency (ms), Throughput (events/second)");
    }

    public SensorReading parseInput(String input) {
        try {
            String[] data = input.toString().split(",");
            return new SensorReading(Long.parseLong(data[0]), data[1], Double.parseDouble(data[2]));
        } catch (Exception e) {
            return new SensorReading(0, "", 0);
        }
    }

    public SensorReading TemperatureConvertorDetector(SensorReading input) {
        input.setAboveThreshold(input.getTemperature() > 70);
        input.setTemperature(roundOfThree((input.getTemperature() * 9 / 5) + 32));
        return input;
    }

    public SensorReading MetricLoggerMap(SensorReading input) {
        long curr_time = System.currentTimeMillis();
        if (curr_time - timeOne > (benchmarkConfig.getMetricLoggingIntervalSec() * 1000L)) {
            long throughput = event_count / benchmarkConfig.getMetricLoggingIntervalSec();
            long latency = System.currentTimeMillis() - input.getTimestamp();
            METRIC_LOGGER.info("{},{}", latency, throughput);
            timeOne = curr_time;
            event_count = 0;
        } else {
            event_count++;
        }
        return input;
    }

    public SensorIdStats MetricLoggerMap(SensorIdStats input) {
        long curr_time = System.currentTimeMillis();
        if (curr_time - timeOne > (benchmarkConfig.getMetricLoggingIntervalSec() * 1000L)) {
            METRIC_LOGGER.info("{},{}", input.getLatency(), input.getThroughput());
        }
        return input;
    }
}
