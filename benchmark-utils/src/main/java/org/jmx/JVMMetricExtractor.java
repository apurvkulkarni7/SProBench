package org.metrics;

import org.apache.commons.cli.CommandLine;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.util.CliParamGenerator;

import java.io.BufferedWriter;
import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.lang.management.RuntimeMXBean;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.util.MetricUtil.jvmMetricExtractorRunner;
import static org.util.MetricUtil.setLoggerProperties;

public class JVMMetricExtractor {
    public static void main(String[] args) {
        // Setting logger properties
//        setLoggerProperties("log4j2-jvm.xml", JVMMetricExtractor.class.getClassLoader());
        setLoggerProperties("log4j2-jvm.properties");

        Logger mainLogger = LogManager.getLogger("main");

        // Get cli argument and parse them
        CommandLine opt = new CliParamGenerator(args).build();

        RuntimeMXBean runtime = ManagementFactory.getRuntimeMXBean();
        long pid = runtime.getPid();
        // Write the PID to the file
        Path path = Path.of(System.getProperty("logDir") + "/" + System.getProperty("mainLogFileName") + ".pid");
        try (BufferedWriter writer = Files.newBufferedWriter(path)) {
            writer.write(Long.toString(pid));
            mainLogger.info("PID written to file: " + path.toAbsolutePath());
        } catch (IOException e) {
            e.printStackTrace();
        }

        // Extracting JVM metrics
        jvmMetricExtractorRunner(opt);
    }
}
