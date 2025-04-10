package org.scadsai.benchmarks.streaming.sparkstrucstreaming;

import org.apache.spark.api.java.function.FilterFunction;
import org.apache.spark.api.java.function.MapFunction;
import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Encoders;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.types.DataTypes;
import org.scadsai.benchmarks.streaming.utils.ConfigLoader.BenchmarkConfig;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorIdStats;
import org.scadsai.benchmarks.streaming.utils.SensorData.SensorReading;

import java.util.Objects;

import static org.apache.spark.sql.functions.*;
import static org.scadsai.benchmarks.streaming.sparkstrucstreaming.MainSparkStrucStreaming.METRIC_LOGGER;

public class Transformations {

    private static BenchmarkConfig benchmarkConfig = null;
    private static MetricLoggerMap metricLoggerMap = null;

    public Transformations(BenchmarkConfig benchmarkConfig) {
        this.benchmarkConfig = benchmarkConfig;
        this.metricLoggerMap = new MetricLoggerMap(benchmarkConfig);
        METRIC_LOGGER.info("Latency (ms), Throughput (events/second)");
    }

    // P0: Pass-through with timestamp processing
    public static Dataset<String> applyP0(Dataset<Row> sourceStream) {
        return sourceStream
                .select(
                        split(col("value"), ",").getItem(0).as("timestamp"),
                        split(col("value"), ",").getItem(1).as("sensorId"),
                        split(col("value"), ",").getItem(2).as("value")
                )
                .withColumn("ingestTimestampRaw", current_timestamp())
                .withColumn("ingestTimestamp",
                        unix_timestamp(col("ingestTimestampRaw"))
                                .multiply(1000L)
                                .plus(expr("CAST(date_format(ingestTimestampRaw, 'SSS') AS LONG)"))
                                .cast(DataTypes.LongType)
                )
                .selectExpr(
                        "CAST(ingestTimestamp AS STRING) AS key",
                        "CAST(concat_ws(',', timestamp, sensorId, value, ingestTimestamp) AS STRING) AS value"
                )
                .toJSON();
    }

    // Common parsing logic used by P1 and P2
    public static Dataset<SensorReading> parseToSensorReading(Dataset<Row> sourceStream) {
        return sourceStream
                .map((MapFunction<Row, SensorReading>) row -> {
                    try {
                        String[] parts = row.getString(0).split(",");
                        if (parts.length == 3) {
                            long timestamp = Long.parseLong(parts[0]);
                            String sensorId = parts[1];
                            double value = Double.parseDouble(parts[2]);
                            return new SensorReading(timestamp, sensorId, value);
                        } else {
                            METRIC_LOGGER.error("Malformed record skipped (wrong number of parts): " + row.getString(0));
                            return null;
                        }
                    } catch (NumberFormatException | ArrayIndexOutOfBoundsException e) {
                        METRIC_LOGGER.error("Error parsing record: " + row.getString(0) + " - " + e.getMessage());
                        return null;
                    }
                }, Encoders.bean(SensorReading.class))
                .filter((FilterFunction<SensorReading>) Objects::nonNull); // Filter out nulls from skipped records
    }

    // P1: Temperature conversion and threshold check
    public static Dataset<String> applyP1(Dataset<SensorReading> parsedStream) {
        return parsedStream
                .map((MapFunction<SensorReading, SensorReading>) reading -> {
                    double tempC = reading.getTemperature();
                    double tempF = (tempC * 9.0 / 5.0) + 32.0;
                    reading.setTemperature(tempF); // Update temperature to Fahrenheit
                    reading.setAboveThreshold(tempF > 70.0);
                    return reading;
                }, Encoders.bean(SensorReading.class))
                .map((MapFunction<SensorReading, SensorReading>) input -> {
                    MetricLoggerMap.logMetrics(input);
                    return input;
                }, Encoders.bean(SensorReading.class))
                .toJSON();
    }

    // P2: Windowed aggregation
    public static Dataset<String> applyP2(Dataset<SensorReading> parsedStream) {
        return
                parsedStream
                        .withColumn("eventTime",
                                (col("timestamp").cast(DataTypes.LongType).$div(1000)).cast(DataTypes.TimestampType))
                        .withWatermark("eventTime", "100 milliseconds")
                        .groupBy(col("sensorId"),
                                window(
                                        col("eventTime"),
                                        benchmarkConfig.getStreamProcessor().getWindowLengthMs() + " milliseconds",
                                        benchmarkConfig.getStreamProcessor().getWindowAdvanceMs() + " milliseconds"
                                ))
                        .agg(
                                round(min("temperature"), 2).cast(DataTypes.DoubleType).as("min"),
                                max("temperature").cast(DataTypes.DoubleType).as("max"),
                                round(avg("temperature"), 2).cast(DataTypes.DoubleType).as("avg"),
                                count("timestamp").cast(DataTypes.LongType).as("count"),
                                max("timestamp").cast(DataTypes.LongType).as("lastTimestamp")
                        )
                        .withColumn("windowLength", lit(benchmarkConfig.getStreamProcessor().getWindowLengthMs()).cast(DataTypes.LongType))
                        .withColumn("throughput", ( // Throughput: events per second
                                col("count")
                                        .multiply(1000L)
                                        .divide(lit(benchmarkConfig.getStreamProcessor().getWindowLengthMs())).cast(DataTypes.LongType)
                        ))
                        .withColumn("latency", (
                                unix_timestamp(col("window.end"))
                                        .cast(DataTypes.DoubleType)
                                        .multiply(1000L)
                                        .minus(col("lastTimestamp"))
                        ))
                        .select(
                                col("sensorId"),
                                col("avg"),
                                col("min"),
                                col("max"),
                                col("windowLength"),
                                col("lastTimestamp"),
                                col("throughput"),
                                col("latency")
                        )
                        .map((MapFunction<Row, SensorIdStats>) row -> {
                            SensorIdStats sensorIdStat = new SensorIdStats();
                            sensorIdStat.updateStatsManual(
                                    row.getString(0), // sensorId
                                    row.getDouble(1), // avg
                                    row.getDouble(2), // min
                                    row.getDouble(3), // max
                                    row.getLong(4), // windowLength
                                    row.getLong(5), // lastTimestamp
                                    row.getLong(6), // throughput
                                    row.getDouble(7) // latency
                            );
                            return sensorIdStat;
                        }, Encoders.bean(SensorIdStats.class))
                        .map((MapFunction<SensorIdStats, SensorIdStats>) input -> {
                            MetricLoggerMap.logMetrics(input);
                            return input;
                        }, Encoders.bean(SensorIdStats.class))
                        .toJSON();
    }
}
