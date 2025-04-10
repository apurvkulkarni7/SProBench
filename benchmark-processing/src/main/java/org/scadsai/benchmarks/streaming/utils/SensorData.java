package org.scadsai.benchmarks.streaming.utils;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.common.serialization.Deserializer;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.common.serialization.Serializer;

public class SensorData {
    public static class SensorReading {
        private long timestamp;
        private String sensorId;
        private double temperature;
        private boolean aboveThreshold;
        private long processedTimestamp;

        public SensorReading() { }

        public SensorReading(long timestamp, String sensorId, double temperature) {
            this.timestamp = timestamp;
            this.sensorId = sensorId;
            this.temperature = temperature;
        }

        public void setTimestamp(long timestamp) { this.timestamp = timestamp; }
        public long getTimestamp() { return timestamp; }

        public void setSensorId(String sensorId) { this.sensorId = sensorId; }
        public String getSensorId() { return sensorId; }

        public double getTemperature() { return temperature; }
        public void setTemperature(double temperature) { this.temperature = temperature; }

        public boolean isAboveThreshold() { return aboveThreshold; }
        public void setAboveThreshold(boolean aboveThreashold) { this.aboveThreshold = aboveThreashold; }

        @Override
        public String toString() {
            return "SensorReading{" +
                    "sensorId='" + sensorId + "'" +
                    ", timestamp=" + timestamp +
                    ", temperature=" + temperature +
                    ", aboveThreshold=" + aboveThreshold +
                    "}";
        }
    }

    public static class SensorIdStats {
        private long lastTimestamp;
        private String sensorId;
        private double min = Double.POSITIVE_INFINITY;
        private double max = Double.NEGATIVE_INFINITY;
        private double avg;
        private long windowLengthMs;
        private long throughput;
        private double latency;

        // Transient fields excluded from encoding
        private transient double sum;
        private transient long count;

        public SensorIdStats() {}

        // Getters and Setters (only those which needs to be encoded)
        public long getLastTimestamp() { return lastTimestamp; }
        public void setLastTimestamp(long lastTimestamp) { this.lastTimestamp = lastTimestamp; }

        public String getSensorId() { return sensorId; }
        public void setSensorId(String sensorId) { this.sensorId = sensorId; }

        public double getMin() { return min; }
        public void setMin(double min) { this.min = min; }

        public double getMax() { return max; }
        public void setMax(double max) { this.max = max; }

        public double getAvg() { return avg; }
        public void setAvg(double avg) { this.avg = avg; }

        public long getWindowLengthMs() { return windowLengthMs; }
        public void setWindowLengthMs(long windowLength_ms) { this.windowLengthMs = windowLength_ms; }

        public long getThroughput() { return throughput; }
        public void setThroughput(long throughput) { this.throughput = throughput; }

        public double getLatency() { return latency; }
        public void setLatency(double latency) { this.latency = latency; }

        public void updateMetrics() {
            this.throughput = count * 1000 / this.windowLengthMs;
            this.latency = System.currentTimeMillis() - this.lastTimestamp;
        }

        public void update(String sensorId, long lastTimestamp, double temperature, long windowLengthMs) {
            this.min = Math.min(min, temperature);
            this.max = Math.max(max, temperature);
            this.sum += temperature;
            this.count++;
            this.avg = sum / count;

            if (lastTimestamp > this.lastTimestamp) {
                this.lastTimestamp = lastTimestamp;
            }

            this.windowLengthMs = windowLengthMs;
            this.sensorId = sensorId;
            updateMetrics();
        }

        public void updateStatsManual(String sensorId, double avg, double min, double max,
                                      long windowLength_ms, long lastTimestamp,
                                      long throughput, double latency) {
            setSensorId(sensorId);
            setAvg(avg);
            setMin(min);
            setMax(max);
            setWindowLengthMs(windowLength_ms);
            setLastTimestamp(lastTimestamp);
            setThroughput(throughput);
            setLatency(latency);

            // Explicitly reset derived transient fields to invalid state
            this.sum = -1;
            this.count = -1;
        }

        @Override
        public String toString() {
            return "SensorIdStats{" +
                    "sensorId='" + sensorId + '\'' +
                    ", timestamp=" + lastTimestamp +
                    ", min=" + min +
                    ", max=" + max +
                    ", avg=" + avg +
                    ", windowLengthMs=" + windowLengthMs +
                    ", throughput=" + throughput +
                    ", latency=" + latency +
                    '}';
        }
    }

    public static class SensorReadingSerializer implements Serializer<SensorReading> {
        private final ObjectMapper objectMapper = new ObjectMapper();

        @Override
        public byte[] serialize(String topic, SensorReading data) {
            try {
                return objectMapper.writeValueAsBytes(data);  // Convert SensorIdStats to JSON bytes
            } catch (Exception e) {
                throw new RuntimeException("Error serializing SensorReading", e);
            }
        }
    }

    public static class SensorReadingDeserializer implements Deserializer<SensorReading> {
        private final ObjectMapper objectMapper = new ObjectMapper();

        @Override
        public SensorReading deserialize(String topic, byte[] data) {
            try {
                return objectMapper.readValue(data, SensorReading.class);  // Convert bytes to SensorIdStats
            } catch (Exception e) {
                throw new RuntimeException("Error deserializing SensorIdStats", e);
            }
        }
    }

    public static class SensorReadingSerde extends Serdes.WrapperSerde<SensorReading> {
        public SensorReadingSerde() {
            super(new SensorReadingSerializer(), new SensorReadingDeserializer());
        }
    }

    public static class SensorIdStatsSerializer implements Serializer<SensorIdStats> {
        private final ObjectMapper objectMapper = new ObjectMapper();

        @Override
        public byte[] serialize(String topic, SensorIdStats data) {
            try {
                return objectMapper.writeValueAsBytes(data);  // Convert SensorIdStats to JSON bytes
            } catch (Exception e) {
                throw new RuntimeException("Error serializing SensorIdStats", e);
            }
        }
    }

    public static class SensorIdStatsDeserializer implements Deserializer<SensorIdStats> {
        private final ObjectMapper objectMapper = new ObjectMapper();

        @Override
        public SensorIdStats deserialize(String topic, byte[] data) {
            try {
                return objectMapper.readValue(data, SensorIdStats.class);  // Convert bytes to SensorIdStats
            } catch (Exception e) {
                throw new RuntimeException("Error deserializing SensorIdStats", e);
            }
        }
    }

    public static class SensorIdStatsSerde extends Serdes.WrapperSerde<SensorIdStats> {
        public SensorIdStatsSerde() {
            super(new SensorIdStatsSerializer(), new SensorIdStatsDeserializer());
        }
    }
}
