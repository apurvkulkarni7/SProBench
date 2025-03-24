package org.metrics;

import org.apache.commons.cli.CommandLine;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.util.CliParamGenerator;

import java.io.BufferedWriter;
import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.util.MetricUtil.kafkaMetricExtractorRunner;
import static org.util.MetricUtil.setLoggerProperties;

public class KafkaMetricExtractor {
    public static void main(String[] args) {
        // Setting logger properties
        setLoggerProperties("log4j2-kafka.properties");

        Logger mainLogger = LogManager.getLogger("main");

        long pid = ManagementFactory.getRuntimeMXBean().getPid();

        // Write the PID to the file
        Path path = Path.of(System.getProperty("logDir") + "/" + System.getProperty("mainLogFileName") + ".pid");
        try (BufferedWriter writer = Files.newBufferedWriter(path)) {
            writer.write(Long.toString(pid));
            mainLogger.info("PID written to file: " + path.toAbsolutePath());
        } catch (IOException e) {
            e.printStackTrace();
        }

        // Get cli argument and parse them
        CommandLine opt = new CliParamGenerator(args).build();
        kafkaMetricExtractorRunner(opt);
    }
}
