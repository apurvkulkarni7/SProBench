package org.scadsai.benchmarks.streaming.generator.cases;

import org.apache.logging.log4j.Logger;
import org.scadsai.benchmarks.streaming.generator.GeneratorMain;
import org.scadsai.benchmarks.streaming.generator.sink.MyKafkaProducer;
import org.scadsai.benchmarks.streaming.generator.type.TemperatureDataGenerator;
import org.scadsai.benchmarks.streaming.generator.utils.ApplicationConfig;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * ConstantInterval represents a benchmark test case that generates data at a constant interval.
 */
public class ConstantInterval {
    private final TemperatureDataGenerator temperatureDataGenerator;
    private MyKafkaProducer kafkaProducer = null;
    private final String label;
    private final Logger logger;
    private final int threadCount;
    final AtomicLong messageCount = new AtomicLong(0);
    final AtomicBoolean isShutdown = new AtomicBoolean(false);
    final AtomicLong startTime = new AtomicLong(System.currentTimeMillis());
    private final ApplicationConfig appConf;

    public ConstantInterval(ApplicationConfig appConf) {
        this.appConf = appConf;
        this.logger = GeneratorMain.MainLogger;
        this.temperatureDataGenerator = appConf.getTemperatureDataGenerator();
        this.label = "Constant Log generator";
        //this.loadHz = appConf.getLoadHz();
        //this.onlyGenerateData = appConf.isOnlyGenerateData();
        if (!appConf.isOnlyGenerateData()) {
            this.kafkaProducer = appConf.getKafkaProducer();
        }
        this.threadCount = appConf.getThreadCount();
    }

    public void run() {
        try {
            //long duration = appConf.getRunTimeMs();
            long period = Math.round(1_000_000_000.0 / appConf.getLoadHzPerThread()); // convert frequency to period in nanoseconds
            logger.info(
                    "Data generator started with following configuration: " +
                            "\n  Label: {}" +
                            "\n  Period (ms): {}" +
                            "\n  Load (Hz) per thread: {}" +
                            "\n  Number of threads: {}" +
                            "\n  Total load (Hz): {}" +
                            "\n  Runtime (minutes): {}" +
                            "\n  Only generate data: {}",
                    label,
                    appConf.getRunTimeMs(),
                    appConf.getLoadHzPerThread(),
                    appConf.getThreadCount(),
                    appConf.getLoadHz(),
                    appConf.getRunTimeMs() / 60000.0,
                    appConf.isOnlyGenerateData()
            );

            ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(this.threadCount);
            ScheduledFuture<?> dataGenerationFuture = scheduler.scheduleAtFixedRate(() -> {
                if (!isShutdown.get()) {
                    String[] logLine = temperatureDataGenerator.generate();
                    if (!appConf.isOnlyGenerateData()) {
                        // kafkaProducer.send(<partition>,<key>,<record>)
                        // data sent: (0 , sensor0 , 1739183658407,sensor0,57.60)
                        kafkaProducer.send(Integer.parseInt(logLine[0]), logLine[1], logLine[2]);
                    }
                    messageCount.incrementAndGet();
                }
            }, 0, period, TimeUnit.NANOSECONDS);
            
            ScheduledFuture<?> loggingFuture = scheduler.scheduleAtFixedRate(() -> {
                try {
                    long throughput = System.currentTimeMillis() - startTime.get() == 0 ? 0 : (messageCount.get() * 1000) /(System.currentTimeMillis() - startTime.get());
                    logger.info("Record count: {}; Throughput: {} records/sec",messageCount.get(),throughput);
                } catch (Exception e) {
                    logger.error("Error in logging task: {}", e.getMessage());
                }
            }, appConf.getLoggingIntervalSec(), appConf.getLoggingIntervalSec(), TimeUnit.SECONDS);

            scheduler.schedule(() -> {
                try {
                    isShutdown.set(true);
                    dataGenerationFuture.cancel(false);
                    loggingFuture.cancel(false);
                    scheduler.shutdown();
                    if (!scheduler.awaitTermination(5, TimeUnit.SECONDS)) {
                        scheduler.shutdownNow();
                    }
                    logger.info("Total Message count: {}", messageCount.get());
                } catch (Exception e) {
                    logger.error("Error during shutdown: {}", e.getMessage());
                    Thread.currentThread().interrupt();
                    scheduler.shutdownNow();
                }
            }, appConf.getRunTimeMs(), TimeUnit.MILLISECONDS);

        } catch (Exception e) {
            kafkaProducer.close();
            logger.error("Program interrupted. Producer closed", e);
        }
    }
}
