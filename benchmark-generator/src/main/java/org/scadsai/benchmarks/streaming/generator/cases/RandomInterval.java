package org.scadsai.benchmarks.streaming.generator.cases;

import org.apache.logging.log4j.Logger;
import org.scadsai.benchmarks.streaming.generator.GeneratorMain;
import org.scadsai.benchmarks.streaming.generator.sink.MyKafkaProducer;
import org.scadsai.benchmarks.streaming.generator.type.TemperatureDataGenerator;
import org.scadsai.benchmarks.streaming.generator.utils.ApplicationConfig;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * RandomInterval represents a benchmark test case that generates data at a random interval.
 */
public class RandomInterval {
    private final TemperatureDataGenerator temperatureDataGenerator;
    private final MyKafkaProducer kafkaProducer;
    private final long runtimeMinutes;
    private final String label;
    private long messageCount;
    private final long minPause; // Miliseconds
    private final long maxPause; // Miliseconds
    private final long bias;
    private final Logger logger;
    private final boolean onlyGenerateData;

    /**
     * Creates a new ConstantInterval instance.
     *
     * @param appConf Application configuration
     */
    public RandomInterval(ApplicationConfig appConf) {
        this.logger = GeneratorMain.MainLogger;
        this.runtimeMinutes = appConf.getRunTimeMs();
        this.kafkaProducer = appConf.getKafkaProducer();
        this.minPause = appConf.getMinPause();
        this.maxPause = appConf.getMaxPause();
        this.bias = appConf.getBias();
        this.temperatureDataGenerator = appConf.getTemperatureDataGenerator();
        this.onlyGenerateData = appConf.isOnlyGenerateData();
        this.label = "Random Log generator";
    }


    public long getRuntime() {
        return runtimeMinutes;
    }
    public TemperatureDataGenerator getGenerator() {
        return temperatureDataGenerator;
    }
    public MyKafkaProducer getProducer() {
        return kafkaProducer;
    }
    public String getLabel() {
        return label;
    }
    public long getMessageCount() {
        return messageCount;
    }

    /**
     * Runs the benchmark test case.
     */
    public void run() {
        try {
            long duration = runtimeMinutes * 60 * 1000; // convert minutes to milliseconds
            logger.info("Simulator started");
            logger.info("Generator Load: Random Interval between {} and {} ms", minPause, maxPause);
            logger.info("Runtime: {} minutes", runtimeMinutes);

            ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);

            scheduler.scheduleAtFixedRate(() -> {
                String[] logLine = temperatureDataGenerator.generate();

                if (!onlyGenerateData) {
                    kafkaProducer.send(logLine[0], logLine[1]);
                    messageCount++;
                }
            }, 0, generateBiasedRandomNumber(), TimeUnit.MILLISECONDS);

            scheduler.schedule(scheduler::shutdown, duration, TimeUnit.MILLISECONDS);
        } catch (Exception e) {
            kafkaProducer.close();
            logger.error("Program interrupted. Producer closed", e);
        } finally {
            logger.info("Simulator stopped");
            logger.info("Total messages sent: {}", messageCount);
        }
    }

    private long generateBiasedRandomNumber() {
        double init = Math.random();
        double myNumber;
        long randomNumber;
        if (init < 0.7) {
            myNumber = Math.random();
            myNumber *= (double) (bias - minPause);
            randomNumber = Math.round(myNumber + minPause);
        } else {
            myNumber = Math.random();
            myNumber *= (double) (maxPause - bias);
            randomNumber = Math.round(myNumber + bias);
        }

        return randomNumber;
    }
}
