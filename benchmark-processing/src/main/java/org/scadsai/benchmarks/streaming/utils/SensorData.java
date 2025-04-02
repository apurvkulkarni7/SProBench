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
        private boolean aboveThreashold;

        public SensorReading() {
        }

        public SensorReading(long timestamp, String sensorId, double temperature) {
            this.timestamp = timestamp;
            this.sensorId = sensorId;
            this.temperature = temperature;
        }

        public long getTimestamp() {
            return timestamp;
        }

        public void setTimestamp(long timestamp) {
            this.timestamp = timestamp;
        }

        public double getTemperature() {
            return temperature;
        }

        public void setTemperature(double temperature) {
            this.temperature = temperature;
        }

        public boolean isAboveThreashold() {
            return this.aboveThreashold;
        }

        public void setAboveThreashold(boolean aboveThreashold) {
            this.aboveThreashold = aboveThreashold;
        }

        public String getSensorId() {
            return sensorId;
        }

        public void setSensorId(String sensorId) {
            this.sensorId = sensorId;
        }

        @Override
        public String toString() {
            return this.timestamp + "," + this.sensorId + "," + this.temperature + "," + this.aboveThreashold;
        }
    }

    public static class SensorIdStats {
        private long lastTimestamp;
        private String sensorId;
        private double sum = 0;
        private double avg = 0;
        private int count = 0;
        private double min = 0;
        private double max = 0;
        private long throughput = 0L;
        private double latency = 0;
        private long windowLength_ms = 1;

        public SensorIdStats() {
        }

        public double getMin() {
            return min;
        }

        public double getMax() {
            return max;
        }

        public double getSum() {
            return sum;
        }

        public int getCount() {
            return count;
        }

        public double getAvg() {
            return avg;
        }

        public long getLastTimestamp() {
            return this.lastTimestamp;
        }

        public void setLastTimestamp(long latestTimestamp) {
            this.lastTimestamp = latestTimestamp;
        }

        public String getSensorId() {
            return this.sensorId;
        }

        public void setSensorId(String sensorId) {
            this.sensorId = sensorId;
        }

        public long getThroughput() {
            return this.throughput;
        }

        public void setThroughput(long throughput) {
            this.throughput = throughput;
        }

        public double getLatency() {
            return this.latency;
        }

        public void setLatency(double latency) {
            this.latency = latency;
        }

        public long getWindowLength_ms() {
            return this.windowLength_ms;
        }

        public void setWindowLength_ms(long windowLength_ms) {
            this.windowLength_ms = windowLength_ms;
        }

        public void updateMetrics() {
            setThroughput(getCount() * 1000 / getWindowLength_ms());
            setLatency(System.currentTimeMillis() - getLastTimestamp());
        }

        public void update(String sensorId, long lastTimestamp, double temperature, long windowLength_ms) {
            min = Math.min(min, temperature);
            max = Math.max(max, temperature);
            sum += temperature;
            count++;
            avg = sum / count;

            setSensorId(sensorId);
            if (lastTimestamp > this.lastTimestamp) {
                setLastTimestamp(lastTimestamp);
            }
            setWindowLength_ms(windowLength_ms);
            updateMetrics();
        }

        @Override
        public String toString() {
            return "TemperatureStats{" +
                    "sensorID=" + sensorId +
                    "min=" + min +
                    ", max=" + max +
                    ", avg=" + avg +
                    ", count=" + count +
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
