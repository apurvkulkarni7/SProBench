package org.scadsai.benchmarks.streaming.utils;

import org.apache.commons.cli.*;

/**
 * Reference: https://commons.apache.org/proper/commons-cli/usage.html
 */
public class OptionsGenerator {

    public String[] args;

    public OptionsGenerator(String[] args) {
        this.args = args;
    }

    public CommandLine build() {
        Options options = new Options();

        // Adding options
        Option help = Option.builder()
                .option("h")
                .longOpt("help")
                .hasArg(false)
                .desc("Prints this message")
                .build();
        options.addOption(help);

        Option parallelism = Option.builder()
                .option("p")
                .longOpt("parallelism")
                .hasArg(true)
                .argName("integer")
                .desc("Parallelism. Usually equal to number of available processors. Default=1")
                .build();
        options.addOption(parallelism);

        Option srcType = Option.builder()
                .option("srctyp")
                .longOpt("source-type")
                .hasArg(true)
                .argName("kafka/file")
                .desc("Source type: kafka/file")
                .build();
        options.addOption(srcType);

        Option srcKafkaTopic = Option.builder()
                .option("srckt")
                .longOpt("source-kafka-topic")
                .hasArg(true)
                .argName("name")
                .desc("Kafka topic from where messages will be ingested by Flink app. Required")
                .build();
        options.addOption(srcKafkaTopic);

        Option srcBootstrapServer = Option.builder()
                .option("srcbs")
                .longOpt("source-bootstrap-server")
                .hasArg(true)
                .argName("host:port")
                .desc("Kafka server address from where messages will be ingested by Flink app. Required")
                .build();
        options.addOption(srcBootstrapServer);

        Option srcGroupId = Option.builder()
                .option("srcgid")
                .longOpt("name")
                .hasArg(true)
                .argName("name")
                .desc("Kafka topic group if from where messages will be ingested by Flink app. (Required)")
                .build();
        options.addOption(srcGroupId);

        Option snkType = Option.builder()
                .option("snktyp")
                .longOpt("sink-type")
                .hasArg(true)
                .argName("kafka/file/stdout/els")
                .desc("Sink type: \"kafka\":Kafka/\"file\":File/\"els\":Elasticsearch/\"stdout\":On CLI.")
                .build();
        options.addOption(snkType);

        Option snkKafkaTopic = Option.builder()
                .option("snkkt")
                .longOpt("sink-kafka-topic")
                .hasArg(true)
                .argName("name")
                .desc("Kafka topic from to where the messages will be sent by Flink app. Required")
                .build();
        options.addOption(snkKafkaTopic);

        Option snkBootstrapServer = Option.builder()
                .option("snkbs")
                .longOpt("sink-bootstrap-server")
                .hasArg(true)
                .argName("host:port")
                .desc("Kafka server address to where messages will be ingested by Flink app. Required")
                .build();
        options.addOption(snkBootstrapServer);

        Option snkGroupId = Option.builder()
                .option("snkgid")
                .longOpt("name")
                .hasArg(true)
                .argName("name")
                .desc("Kafka topic group if to where messages will be ingested by Flink app. (Required)")
                .build();
        options.addOption(snkGroupId);

        Option srcFile = Option.builder()
                .option("srcfile")
                .longOpt("source-file")
                .hasArg(true)
                .argName("full path of the source file")
                .desc("File from where the data is ingested.")
                .build();
        options.addOption(srcFile);

        Option snkFile = Option.builder()
                .option("snkfile")
                .longOpt("sink-file")
                .hasArg(true)
                .argName("full path of the sink file")
                .desc("File to where the processed data will be written.")
                .build();
        options.addOption(snkFile);

        Option runtime = Option.builder()
                .option("runtime")
                .longOpt("runtime")
                .hasArg(true)
                .argName("runtime")
                .desc("Runtime of the processing.")
                .build();
        options.addOption(runtime);

        Option processingType = Option.builder()
                .option("pt")
                .longOpt("processing-type")
                .hasArg(true)
                .argName("P0|P1|P2")
                .desc("Processin type. P0-passthrough, P1-only parsing, P2-parsing and temperatureconversion")
                .build();
        options.addOption(processingType);

        // create the parser
        CommandLineParser parser = new DefaultParser();

        CommandLine cmd = null;
        try {
            // parse the command line arguments
            cmd = parser.parse(options, this.args);
            if (cmd.hasOption("help")) {
                // automatically generate the help statement
                HelpFormatter formatter = new HelpFormatter();
                formatter.printHelp("<jar-file>", options);
                System.exit(0);
            }
//            if (!cmd.hasOption("help") ){
//                if (!(cmd.hasOption("kt") && cmd.hasOption("bs"))) {
//                    Exception e = new ParseException("All required arguments are not provided. "+
//                            "Please refer help (-h) for more information");
//                    e.printStackTrace();
//                }
//            }
        } catch (ParseException exp) {
            // oops, something went wrong
            System.err.println("Parsing failed.  Reason: " + exp.getMessage());
        }
        return cmd;
    }
}