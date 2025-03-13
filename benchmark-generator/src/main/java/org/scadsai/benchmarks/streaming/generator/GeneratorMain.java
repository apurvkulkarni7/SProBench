package org.scadsai.benchmarks.streaming.generator;

import org.apache.commons.cli.ParseException;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.scadsai.benchmarks.streaming.generator.cases.ConstantInterval;
import org.scadsai.benchmarks.streaming.generator.cases.RandomInterval;
import org.scadsai.benchmarks.streaming.generator.utils.ApplicationConfig;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class GeneratorMain {
    public static final Logger MainLogger = LogManager.getLogger("main");

    public static void main(String[] args) {
        ApplicationConfig appConf = null;
        try {
            appConf = new ApplicationConfig(args);
        } catch (ParseException e) {
            throw new RuntimeException(e);
        }

        // Multithreaded approach
//        int numOfThreads = appConf.getThreadCount(); // number of threads to create
//        ExecutorService executor = Executors.newFixedThreadPool(numOfThreads);

//        for (int i = 0; i < numOfThreads; ++i) {
            // code to run in each thread
        if (appConf.getGeneratorType().equals("constant")) {
            new ConstantInterval(appConf).run();
        } else if (appConf.getGeneratorType().equals("random")) {
            new RandomInterval(appConf).run();
        }
    }

//        executor.shutdown();
//    }
}
