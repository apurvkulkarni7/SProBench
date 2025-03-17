package org.scadsai.benchmarks.streaming.generator.utils;

import org.apache.commons.cli.*;
import org.apache.logging.log4j.LogManager;
import org.scadsai.benchmarks.streaming.generator.sink.MyKafkaProducer;
import org.scadsai.benchmarks.streaming.generator.type.TemperatureDataGenerator;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;
import java.util.logging.Logger;

/**
 * ApplicationConfig represents the configuration for the benchmark application.
 */
public class ApplicationConfig {
    private static final Logger logger = Logger.getLogger(ApplicationConfig.class.getName());
    private static final org.apache.logging.log4j.Logger log = LogManager.getLogger(ApplicationConfig.class);

    //private String databaseFile;
    private String kafkaTopic;
    private String bootstrapServer;
    private final long runTimeMs;
    private final long loadHz;
    private final int threadCount;
    private final long loadHzPerThread;
    private final int recordSizeB;
    private long maxPause;
    private final String generatorType;
    private final TemperatureDataGenerator temperatureDataGenerator;
    private MyKafkaProducer kafkaProducer;
    private final int numberOfSensors;

    private final boolean onlyGenerateData;
    private long minPause;
    private long bias;
    private Properties producerProperties;
    private final long loggingIntervalSec;

    /**
     * Creates a new ApplicationConfig instance based on the provided command-line arguments.
     */
    public ApplicationConfig(String[] args) throws ParseException {
        Options options = OptionsGenerator.generateOptions();
        CommandLine commandLine = new DefaultParser().parse(options, args);

        if (commandLine.hasOption("help")) {
            printHelp(options);
            System.exit(0);
        }

        this.runTimeMs = Long.parseLong(commandLine.getOptionValue("run-time-min", "1800000")) * 60 * 1000; // convert minutes to milliseconds
        this.generatorType = commandLine.getOptionValue("generator-type", "constant");
        this.onlyGenerateData = commandLine.hasOption("only-generate-data");
        this.recordSizeB = Integer.parseInt(commandLine.getOptionValue("record-size", "27"));
        this.numberOfSensors = Integer.parseInt(commandLine.getOptionValue("number-of-sensors")); // This also decides number of partition in kafka topic??
        this.temperatureDataGenerator = new TemperatureDataGenerator(getNumberOfSensors(),getRecordSizeB());
        this.loggingIntervalSec = Long.parseLong(commandLine.getOptionValue("logging-interval-sec", "1"));
        this.threadCount = Integer.parseInt(commandLine.getOptionValue("thread-count", "1"));
        this.loadHz = Long.parseLong(commandLine.getOptionValue("loadHz", "1"));
        this.loadHzPerThread =  getLoadHz() / getThreadCount();

        if (getGeneratorType().equals("random")) {
            this.minPause = Long.parseLong(commandLine.getOptionValue("min-pause", "10"));
            this.maxPause = Long.parseLong(commandLine.getOptionValue("max-pause", "10000"));
            this.bias = Long.parseLong(commandLine.getOptionValue("bias", "50"));
        }

        if (!isOnlyGenerateData()) {
            setProducerProperties(commandLine.getOptionValue("producer-properties-file"));
            // following can be removed by setting these values in the producer.properties
            // following is suitable for only single node kafka cluster
            this.kafkaTopic = commandLine.getOptionValue("kafka-topic");
            getProducerProperties().put("topic",getKafkaTopic());
            this.bootstrapServer = commandLine.getOptionValue("bootstrap-server");
            getProducerProperties().put("bootstrap.servers",getBootstrapServer());
            this.kafkaProducer = new MyKafkaProducer(getProducerProperties());
        }
    }

    private void printHelp(Options options) {
        HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp("Benchmark Application", options);
        System.exit(0);
    }

    public String getKafkaTopic() { return kafkaTopic; }
    public String getBootstrapServer() { return bootstrapServer;}
    public long getRunTimeMs() {return runTimeMs;}
    public long getLoggingIntervalSec() {return loggingIntervalSec;}
    public long getLoadHz(){return loadHz;}
    public String getGeneratorType() {return generatorType;}
    public TemperatureDataGenerator getTemperatureDataGenerator() {return temperatureDataGenerator;}
    public MyKafkaProducer getKafkaProducer() {return kafkaProducer;}
    public int getRecordSizeB() {return recordSizeB;}
    public int getNumberOfSensors() {return numberOfSensors;}
    public int getThreadCount() {return threadCount;}
    public long getLoadHzPerThread() { return loadHzPerThread; }
    public long getMaxPause() {return maxPause;}
    public long getMinPause() {return minPause;}
    public long getBias() {return bias;}
    public boolean isOnlyGenerateData() {return onlyGenerateData;}
    public Properties getProducerProperties() {return this.producerProperties;}
    public void setProducerProperties(String producerPropertiesFile) {
        Properties producerProperties = new Properties();
        try (FileInputStream input = new FileInputStream(producerPropertiesFile)) {
            producerProperties.load(input);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        this.producerProperties = producerProperties;
    }
}

class OptionsGenerator {
    public static Options generateOptions() {
        Options options = new Options();
        options.addOption("h", "help", false, "Print help message");
        options.addOption("d", "database-file", true, "Path to the database file (default: database.csv)");
        options.addOption("kt", "kafka-topic", true, "Kafka topic to produce to");
        options.addOption("bs", "bootstrap-server", true, "Kafka bootstrap server");
        options.addOption("rt", "run-time-min", true, "Runtime in minutes (default: 5)");
        options.addOption("gt", "generator-type", true, "Type of generator to use (default: constant)");
        options.addOption("nos", "number-of-sensors", true, "Number of sensors (default: 1)");
        options.addOption("tc", "thread-count", true, "Number of threads to use (default: 1)");
        options.addOption("l", "loadHz", true, "Load in Hz (default: 1000)");
        options.addOption("ogd", "only-generate-data", false, "Only generate data without sending to Kafka");
        options.addOption("mxp", "max-pause", true, "Maximum pause between randomly generated data (Millisecond)");
        options.addOption("mnp", "min-pause", true, "Minimum pause between randomly generated data (Millisecond)");
        options.addOption("bias", "bias", true, "Bias for the randomly generated data");
        options.addOption("ppf", "producer-properties-file", true, "Path to the producer properties file.");
        options.addOption("li", "logging-interval-sec", true, "Logging interval for throughput and message count");
        options.addOption("rs", "record-size", true, "Size of each record in Bytes (Default: 27)");
        return options;
    }
}