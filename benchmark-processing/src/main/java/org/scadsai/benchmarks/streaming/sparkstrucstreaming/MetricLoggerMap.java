package org.scadsai.benchmarks.streaming.sparkstrucstreaming;

import java.util.function.Function;
import org.scadsai.benchmarks.streaming.utils.ConfigLoader.BenchmarkConfig;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorReading;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorIdStats;
import java.util.concurrent.atomic.AtomicLong;
import static org.scadsai.benchmarks.streaming.sparkstrucstreaming.MainSparkStrucStreaming.METRIC_LOGGER;

public class MetricLoggerMap {
    private static final AtomicLong eventCount = new AtomicLong(0);
    private static final AtomicLong lastLogTime = new AtomicLong(0);
    private static BenchmarkConfig benchmarkConfig = null;

    public MetricLoggerMap(BenchmarkConfig benchmarkConfig) {
        MetricLoggerMap.benchmarkConfig = benchmarkConfig;
    }

    // Generic method to handle both SensorReading and SensorIdStats
    public static <T> T logMetrics(T input, Function<T, Long> timestampExtractor) {
        final long currentTime = System.currentTimeMillis();
        final long logIntervalMillis = benchmarkConfig.getMetricLoggingIntervalSec() * 1000L;

        // Check if it's time to log metrics
        if (currentTime - lastLogTime.get() > logIntervalMillis) {
            // Atomically update and reset only once per interval
            final long events = eventCount.getAndSet(0);
            lastLogTime.set(currentTime);

            // Calculate metrics with floating point precision
            double throughput = (long) (events / benchmarkConfig.getMetricLoggingIntervalSec());
            long latency = currentTime - timestampExtractor.apply(input);
            METRIC_LOGGER.info("{}, {}", latency, String.format("%.2f", throughput));
        } else {
            eventCount.getAndIncrement();
        }

        return input;
    }

    // Type-specific methods for cleaner API
    public static SensorReading logMetrics(SensorReading input) {
        return logMetrics(input, SensorReading::getTimestamp);
    }

    public static SensorIdStats logMetrics(SensorIdStats input) {
        return logMetrics(input, SensorIdStats::getLastTimestamp);
    }
}