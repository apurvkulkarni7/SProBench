package org.scadsai.benchmarks.streaming.kafkastream;

import org.apache.commons.cli.*;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsConfig;
import org.scadsai.benchmarks.streaming.utils.ConfigLoader;
import org.scadsai.benchmarks.streaming.utils.ConfigLoader.BenchmarkConfig;

import java.util.Properties;

/**
 * Reference: https://commons.apache.org/proper/commons-cli/usage.html
 */
public class OptionsGenerator {

    public String[] args;
    public Properties properties;
    public BenchmarkConfig config;

    public OptionsGenerator(String[] args) {
        this.args = args;
        this.build();
    }

    public void build() {
        Options options = new Options();

        // Adding options
        Option help = Option.builder()
                .option("h")
                .longOpt("help")
                .hasArg(false)
                .desc("Prints this message")
                .build();
        options.addOption(help);

        Option bootstrapServer = Option.builder()
                .option("bs")
                .longOpt("bootstrap-servers")
                .hasArg(true)
                .argName("bootstrap-servers")
                .desc("Bootstrap Server on which worker kafka cluster is running")
                .build();
        options.addOption(bootstrapServer);

        Option configFile = Option.builder()
                .option("c")
                .longOpt("config-file")
                .hasArg(true)
                .argName("configuration file")
                .desc("Benchmark configuration file to read from")
                .build();
        options.addOption(configFile);

        // create the parser
        CommandLineParser parser = new DefaultParser();

        CommandLine cmd = null;
        Properties props = null;
        try {
            // parse the command line arguments
            cmd = parser.parse(options, this.args);
            if (cmd.hasOption("help")) {
                // automatically generate the help statement
                HelpFormatter formatter = new HelpFormatter();
                formatter.printHelp("<jar-file>", options);
                System.exit(0);
            }

            String yamlFile = cmd.getOptionValue("config-file");
            String bootstrapServers = cmd.getOptionValue("bootstrap-servers");

            BenchmarkConfig config = new ConfigLoader(yamlFile).parser();
            this.config = config;
            props = new Properties();
            props.put(StreamsConfig.APPLICATION_ID_CONFIG, "SProBench_KafkaStream");
            props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers); // multiple bootstrap servers for scaleout
            // should be of the form: kafka1:9092,kafka2:9092,kafka3:9092"
            props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
            props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
            props.put(StreamsConfig.STATE_DIR_CONFIG, config.getStreamProcessor().getStateDir());
            props.put(StreamsConfig.NUM_STREAM_THREADS_CONFIG, config.getStreamProcessor().getWorker().getParallelism()); // parallelism
            props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, StreamsConfig.EXACTLY_ONCE_V2); // parallelism

            this.properties = props;

        } catch (ParseException exp) {
            // oops, something went wrong
            System.err.println("Parsing failed.  Reason: " + exp.getMessage());
        }
    }

    public Properties getProperties() {
        return this.properties;
    }

    public BenchmarkConfig getConfig() {
        return this.config;
    }
}

