package org.scadsai.benchmarks.streaming.utils;

public class SensorReading {
    public long timestamp;
    public String sensorId;
    public double temperature;
    public boolean aboveThreashold;
    public double movingAverage;

    public SensorReading(long timestamp, String sensorId, double temperature) {
        this.timestamp = timestamp;
        this.sensorId = sensorId;
        this.temperature = temperature;
    }

    @Override
    public String toString() {
        return this.timestamp + "," + this.sensorId + "," + this.temperature + "," + this.aboveThreashold + "," + this.movingAverage;
    }
}