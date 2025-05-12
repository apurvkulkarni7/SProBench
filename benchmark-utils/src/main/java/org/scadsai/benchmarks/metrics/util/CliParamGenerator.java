package org.scadsai.benchmarks.metrics.util;
import org.apache.commons.cli.*;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public class CliParamGenerator {

    public static final Logger mainLogger = LogManager.getLogger("main");

    public String[] args;

    public CliParamGenerator(String[] args) {
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

        Option retrievingType = Option.builder()
                .option("rt")
                .longOpt("retrieving-type")
                .hasArg(true)
                .argName("host-port/pid")
                .desc("Retrieve jmx metrics using either hostname and port or using process id")
                .build();
        options.addOption(retrievingType);

        Option pid = Option.builder()
                .option("pid")
                .longOpt("process-id")
                .hasArg(true)
                .argName("integer")
                .desc("Process ID of a JVM/Java process")
                .build();
        options.addOption(pid);

        Option hostname = Option.builder()
                .option("hn")
                .longOpt("hostname")
                .hasArg(true)
                .argName("hostname")
                .desc("Hostname of the machine")
                .build();
        options.addOption(hostname);

        Option port = Option.builder()
                .option("p")
                .longOpt("port")
                .hasArg(true)
                .argName("port")
                .desc(" Port where jmx server is running on the host machine")
                .build();
        options.addOption(port);

        Option queryAll = Option.builder()
                .option("a")
                .longOpt("all")
                .hasArg(false)
                .desc("To get all available jmx metrics")
                .build();
        options.addOption(queryAll);

        Option queryName = Option.builder()
                .option("q")
                .longOpt("query")
                .hasArg(true)
                .argName("query object name")
                .desc("Name of the query object whose metrics are required")
                .build();
        options.addOption(queryName);

        Option queryObjectAttributeName = Option.builder()
                .option("qa")
                .longOpt("query-attribute")
                .hasArg(true)
                .argName("query object attribute name")
                .desc("Name of the query object attribute whose metrics are required")
                .build();
        options.addOption(queryObjectAttributeName);

        Option loggingInterval = Option.builder()
                .option("li")
                .longOpt("logging-interval")
                .hasArg(true)
                .argName("milliseconds")
                .desc("Interval between two logging requests (Default: 5000)")
                .build();
        options.addOption(loggingInterval);

        Option getMetricList = Option.builder()
                .option("gml")
                .longOpt("get-metric-list")
                .hasArg(false)
                .desc("Print the list of available metrics to a file")
                .build();
        options.addOption(getMetricList);

        Option fileName = Option.builder()
                .option("of")
                .longOpt("output-file")
                .hasArg(true)
                .argName("file name")
                .desc("File to which list of available metrics will be printed")
                .build();
        options.addOption(fileName);

        Option inputQueryFile = Option.builder()
                .option("iqf")
                .longOpt("input-query-file")
                .hasArg(true)
                .argName("file name")
                .desc("File which contains list of available metrics whose data needs to be extracted")
                .build();
        options.addOption(inputQueryFile);

        Option javaProcessName = Option.builder()
                .option("jpn")
                .longOpt("java-process-name")
                .hasArg(true)
                .argName("java process name")
                .desc("Name of the java process which needs to be traced")
                .build();
        options.addOption(javaProcessName);

        Option kafkaTopicList = Option.builder()
                .option("ktl")
                .longOpt("kafka-topic-list")
                .hasArg(true)
                .argName("kafka-topics-separated-by-comma")
                .desc("Kafka topics separated by comma, whose metrics needs to be extracted")
                .build();
        options.addOption(kafkaTopicList);

        Option kafkaBootstrapServer = Option.builder()
                .option("kbs")
                .longOpt("kafka-bootstrap-server")
                .hasArg(true)
                .argName("<host>:<port>")
                .desc("Kafka bootstrap server")
                .build();
        options.addOption(kafkaBootstrapServer);

//        Option regexPattern = Option.builder()
//                .option("rgx")
//                .longOpt("regex-pattern")
//                .hasArg(true)
//                .desc("Regex pattern to extract timestamp from kafka topic event.")
//                .build();
//        options.addOption(regexPattern);

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

            if (!cmd.hasOption("retrieving-type")){
                throw new ParseException("Required arguments --retrieving-type (-rt) is missing.");
            }
            if (cmd.getOptionValue("retrieving-type").equals("host-port") && !(cmd.hasOption("hostname") && cmd.hasOption("port")) ){
                throw new ParseException("Required arguments --hostname (-hn) and/or --port (-p) are missing.");
            } else if (cmd.hasOption("retrieving-type") && (cmd.getOptionValue("retrieving-type")=="host-port")) {
                if (!cmd.hasOption("pid")){
                    throw new ParseException("Required arguments --process-id (-pid) is missing.");
                }
            }

            if (!cmd.hasOption("get-metric-list")) {
                if (!(cmd.hasOption("all") || cmd.hasOption("query") || cmd.hasOption("input-query-file"))) {
                    throw new ParseException("Required arguments --all (-a) or --query (-q) and --query-attribute (-qa) or --input-query-file (-iqf) are missing.");
                }
                if (cmd.hasOption("query") && !cmd.hasOption("query-attribute")) {
                    mainLogger.warn("Specific attribute for the query is not mentioned. All attribute information will be gathered.");
                }
            }

        } catch (ParseException exp) {
            // oops, something went wrong
            System.out.println(exp.getMessage());
            System.exit(1);
        }
        return cmd;
    }
}