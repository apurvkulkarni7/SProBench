package org.scadsai.benchmarks.streaming.generator.type;

import org.apache.commons.lang3.RandomStringUtils;

import java.io.UnsupportedEncodingException;
import java.util.Random;

public class TemperatureDataGenerator {
    public int sensorIdCounter_ = -1;
    private static double mean_ = 70.0;
    private static double std_ = 15.0;
    public static int numberOfSensors_;
    public static int recordSize_;
    public static String fillerString_;
    public TemperatureDataGenerator(int numberOfSensors, int recordSize) {
        numberOfSensors_ = numberOfSensors;
        recordSize_ = recordSize;

        String record = generateTimestamp() + "," + generateSensorId() + "," + generateTemperature();
        int fillerStringSize;
        try {
            // To get encoding available on the system, run:
            // java -XshowSettings
            // Look for: sun.jnu.encoding = ANSI_X3.4-1968
            fillerStringSize = recordSize_ - record.getBytes("ANSI_X3.4-1968").length;
        } catch (UnsupportedEncodingException e) {
            throw new RuntimeException(e);
        }
        if (fillerStringSize != 0) {
            fillerString_ = RandomStringUtils.randomAlphabetic(fillerStringSize);
        } else {
            fillerString_ = "";
        }
        sensorIdCounter_ = -1;
    }

    public String[] generate() {
        String timestamp = generateTimestamp();
        String sensorId = generateSensorId();
        String temperature = generateTemperature();
        String record = timestamp + "," + "sensor" + sensorId + "-" + fillerString_ + "," +temperature;

        // partition , key , record
        // 1-N, sensor[1-N], timestamp,sensor[1-N],temp
        return new String[] {sensorId, "sensor" + sensorId, record};
    }

    private static String generateTimestamp() {
        return String.valueOf(System.currentTimeMillis());
    }

    private String generateSensorId() {
        if (this.sensorIdCounter_ < numberOfSensors_ - 1) {
            ++this.sensorIdCounter_;
        } else {
            this.sensorIdCounter_ = 0;
        }
        return String.format("%02d",this.sensorIdCounter_); // padding with 0 for single digit
    }

    private static String generateTemperature() {
        Random random = new Random();
        double u1 = 1.0 - random.nextDouble();
        double u2 = 1.0 - random.nextDouble();
        double z = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(6.283185307179586 * u2);
        double temperature = mean_ + std_ * z;
        return String.format("%.2f",temperature);
    }

}


