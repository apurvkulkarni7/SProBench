package org.scadsai.benchmarks.streaming.flink.utils;

import org.apache.flink.api.common.functions.RichMapFunction;
import org.apache.flink.configuration.Configuration;
import org.apache.kafka.streams.KeyValue;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.scadsai.benchmarks.streaming.utils.SensorReading;

public class MetricLoggerMap<T> extends RichMapFunction<T, T> {
    private static final Logger MetricLogger = LogManager.getLogger("metric");
    private String processingType;
    private final String identifier;
    private final Long loggingIntervalMs;
    private long totalReceived = 0L;
    private long throughput;
    private long latencyTotal =0;
    private long latency =0;
    private long timeOne = 0L;
    private long now;
    private long timeTwo;
    private StringBuilder logStringBuilder;
    private boolean printHeader = true;

    public MetricLoggerMap() {
        this.identifier = "metric";
        this.processingType = "P1";
        this.loggingIntervalMs = 10000L;
    }

    public MetricLoggerMap(String identifier) {
        this.identifier = identifier;
        this.processingType = "P1";
        this.loggingIntervalMs = 10000L;
    }

    public MetricLoggerMap(String identifier, String processingType) {
        this.identifier = identifier;
        this.processingType = processingType;
        this.loggingIntervalMs = 10000L;
    }

    public MetricLoggerMap(String identifier, String processingType, Long loggingIntervalMs) {
        this.identifier = identifier;
        this.processingType = processingType;
        this.loggingIntervalMs = loggingIntervalMs;
    }

    @Override
    public void open(Configuration parameters) {
        // String regex = "^([0-9]+),";
        // this.pattern = Pattern.compile(regex);
        this.logStringBuilder = new StringBuilder();
    }

    public T map(T element) {
        this.timeTwo = System.currentTimeMillis();

        ++this.totalReceived;

        if (this.processingType.equals("P0")) {
        this.latencyTotal += this.timeTwo - Long.valueOf(element.toString().split(",")[0]);
        } else if (this.processingType.equals("P1") || this.processingType.equals("P2")) {
            this.latencyTotal += this.timeTwo - (Long) ((SensorReading) element).timestamp;
        }


        if (this.timeTwo - this.timeOne >= this.loggingIntervalMs) {
            this.timeOne = this.timeTwo;
            this.now = System.currentTimeMillis();
            this.throughput = Math.round((double) this.totalReceived * 1000 / (double) this.loggingIntervalMs);
            this.latency = this.latencyTotal / this.totalReceived;

            if (this.printHeader) {
                MetricLogger.info("timestamp,identifier,thread_info,throughput_events_per_sec_per_core,latency_ms,size_processed_mb_per_sec");
                this.printHeader = false;
            }
            
            // 1704796807889,sensor0,77.2064959715134 -> size is 38 bytes in UTF_8 encoding
            //double dataSizeProcessedMb = (double) this.totalReceived * ((double) 38.0 / ((double) 1000000.0));
            double dataSizeProcessedMbPerSec =  (double) this.totalReceived * element.toString().getBytes().length * 0.001 / (double) (this.loggingIntervalMs);
            this.logStringBuilder.setLength(0);
            this.logStringBuilder.append(this.now)
                .append(",").append(this.identifier)
                .append(",").append(Thread.currentThread().getName())
                .append(",").append(this.throughput)
                .append(",").append(this.latency)
                .append(",").append(dataSizeProcessedMbPerSec);
            
            MetricLogger.info(this.logStringBuilder.toString());

            //String logString = this.now + "," + this.identifier + "," + Thread.currentThread().getName() + "," + this.throughput + "," + this.latency + "," + dataSizeProcessedMb ; // + "," + this.totalReceived;
            //MetricLogger.info(logString);
            
            // Resetting the counter
            this.totalReceived=0;
        }

        return element;
    }

}
