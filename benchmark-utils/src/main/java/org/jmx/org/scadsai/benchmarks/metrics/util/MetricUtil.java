package org.metrics.org.scadsai.benchmarks.metrics.util;

import com.sun.tools.attach.AgentInitializationException;
import com.sun.tools.attach.AgentLoadException;
import com.sun.tools.attach.AttachNotSupportedException;
import com.sun.tools.attach.VirtualMachine;
import org.apache.commons.cli.CommandLine;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.core.config.Configurator;

import javax.management.*;
import javax.management.remote.JMXConnectorFactory;
import javax.management.remote.JMXServiceURL;
import java.io.*;
import java.util.*;
import java.util.function.Supplier;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class MetricUtil {

    //public static final Logger throughputLogger = LogManager.getLogger("throughput");
    //public static final Logger latencyLogger = LogManager.getLogger("latency");
    public static final Logger throughputLatencyLogger = LogManager.getLogger("throughputLatency");
    private static final Logger mainLogger = LogManager.getLogger("main");
    private static final Logger jvmLogger = LogManager.getLogger("jvm");

    
    public static final int RETRY_WAIT_DURATION_SEC = 10;
    public static final int MAX_RETRY = 10;

    public static String metricDelimiter = "###";
    public static boolean getJvmHeader = true;
    
    public static void setLoggerProperties(String log4j2PropertiesFile){

        // SimpleLogger properties for kafka-client
        System.setProperty("org.slf4j.simpleLogger.StatusLogger.level", "info");
        System.setProperty("org.slf4j.simpleLogger.showThreadName", "true");
        System.setProperty("#org.slf4j.simpleLogger.showLogName", "true");
        System.setProperty("org.slf4j.simpleLogger.showShortLogName", "true");
        System.setProperty("org.slf4j.simpleLogger.showDateTime", "true");
        System.setProperty("org.slf4j.simpleLogger.dateTimeFormat", "[yyyy-MM-dd HH:mm:ss:SSS]");
        System.setProperty("org.slf4j.simpleLogger.logFileEncoding", "${file.encoding},append");
        System.setProperty("org.slf4j.simpleLogger.logFile", System.getProperty("logDir") + "/kafka-metric-extractor-client.log");

        // Other logger
//        ClassLoader classLoader = MetricUtil.class.getClassLoader();
//        URL url = classLoader.getResource(log4j2PropertiesFile);
//        Configurator.initialize(null, url.getPath());
//        LoggerContext context = Configurator.initialize(null, log4j2PropertiesFile);
        Configurator.initialize(null, log4j2PropertiesFile);

    }

    public static String getPIDUsingName(String processName){
        String []command ={"/bin/bash","-c","jps | grep -P '" + processName + "$' | awk '{print $1}' | sort -u | head -1"};
        Process exec = null;
        try {
            exec = Runtime.getRuntime().exec(command,null,null);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        java.util.Scanner s = new java.util.Scanner(exec.getInputStream()).useDelimiter("\\A");
        return s.next().replace("\n","");
    }

    public static String getConnectorAddress(String pid) {
        String connectorAddressInitial = "com.sun.management.jmxremote.localConnectorAddress";
        
        // attach to the target application
        VirtualMachine vm = null;
        String connectorAddress = null;
        try {
            
            vm = VirtualMachine.attach(pid);

            // get the connector address
            // connectorAddress = vm.getAgentProperties().getProperty(connectorAddressInitial);
            connectorAddress = vm.startLocalManagementAgent();
            // no connector address, so we start the JMX agent
            if (connectorAddress == null) {
                String agent = vm.getSystemProperties().getProperty("java.home") + File.separator + "lib" + File.separator + "management-agent.jar";
                File f = new File(agent);
                if (!f.exists()) {
                    throw new RuntimeException("management-agent.jar missing");
                }

                mainLogger.info("Loading " + agent + " into target VM ...");
                vm.loadAgent(agent);

                // agent is started, get the connector address
                connectorAddress = vm.getAgentProperties().getProperty(connectorAddressInitial);
            }
        } catch (IOException | AttachNotSupportedException | AgentLoadException | AgentInitializationException e) {
            mainLogger.error("No process found. The process is either unreachable or stopped.", e.getStackTrace());
             System.exit(1);
        } catch (RuntimeException e)
        {
            mainLogger.error("{}", e.getStackTrace());
        }
        return connectorAddress;
    }

    public static MBeanServerConnection getMBeansServerConnection(CommandLine opt){
        try {
            String connectorAddress = null;

            if (opt.getOptionValue("retrieving-type").equals("pid")) {
                // for java 1.8/8
                // connectorAddress = ConnectorAddressLink.importFrom(Integer.parseInt(opt.getOptionValue("process-id")));

                //for java 9+
                // attach to the target application
                // VirtualMachine vm = VirtualMachine.attach(opt.getOptionValue("process-id"));
                // VirtualMachine vm = startManagementAgent(opt.getOptionValue("process-id"));
                // connectorAddress = vm.getAgentProperties().getProperty(connectorAddressInitial);
                if(opt.hasOption("jpn")) {
                    int maxRetryCount = MAX_RETRY;
                    int retryCount = 0;
                    while (true) {
                        if (retryCount == 0) {
                            mainLogger.info("Waiting for process \"" + opt.getOptionValue("java-process-name") + "\" to initialize.");
                        }
                        try {
                            String processPID = MetricUtil.getPIDUsingName(opt.getOptionValue("java-process-name"));
                            connectorAddress = getConnectorAddress(opt.getOptionValue("process-id", processPID));
                            mainLogger.info("Process \"" + opt.getOptionValue("java-process-name") + "\" (pid:" + processPID + ") attached");
                            break;
                        } catch (Exception e) {
                            if (retryCount <= maxRetryCount) {
                                mainLogger.warn("\tRetry {}", retryCount);
                                Thread.sleep(RETRY_WAIT_DURATION_SEC * 1000);
                                retryCount++;
                            } else {
                                mainLogger.error("Maximum number of retries has been reached. No process-id for process \"" +
                                        opt.getOptionValue("java-process-name") + "\" is found.", e);
                                System.exit(1);
                            }
                        }
                    }
                } else {
                    try {
                        mainLogger.debug("Inside the loop where process-id is provided.");
                        //String processPID = MetricUtil.getPIDUsingName(opt.getOptionValue("java-process-name"));
                        //String processPID = opt.getOptionValue("process-id");
                        String processPID = opt.getOptionValue("process-id");
                        mainLogger.debug("Given process-id", processPID);
                        connectorAddress = getConnectorAddress(processPID);
                        mainLogger.debug(connectorAddress);
                        mainLogger.info("Process \"" + "(pid:" + processPID + ") attached");
                    } catch (Exception e) {
                        mainLogger.error("Process for the provided process-id (" + opt.getOptionValue("process-id") + ") does not exits.", e);
                        System.exit(1);
                    }
                }
            } else if (opt.getOptionValue("retrieving-type").equals("host-port")) {
                connectorAddress = "service:jmx:rmi://" + opt.getOptionValue("hostname") + "/jndi/rmi://" + opt.getOptionValue("hostname") + ":" + opt.getOptionValue("port") + "/jmxrmi";
            }
            JMXServiceURL jmxUrl = new JMXServiceURL(connectorAddress);

            // Get MBeans server connection using PID
            return JMXConnectorFactory.connect(jmxUrl).getMBeanServerConnection();

        } catch (IOException | InterruptedException e) {
            throw new RuntimeException(e);
        }
    }

    public static void getMetricsFromInputFile(MBeanServerConnection mbs, List<HashMap<String,String>> queryParams, CommandLine opt) {
        try {

//            String loggingTimestamp = Instant.now().toString();
            String loggingTimestamp = String.valueOf(System.currentTimeMillis()); //Instant.now().toString();

            // Initialize new key-value map
            Map<String, String> myMetricI = new HashMap<>();

            //int ii = 0;
            for (HashMap<String,String> map: queryParams) {
                for (Map.Entry<String, String> entry : map.entrySet()) {

                    String mykey = entry.getKey();
                    AttributeList myvalue = mbs.getAttributes(ObjectName.getInstance(entry.getKey()), new String[]{entry.getValue()});

                    Pattern keyPattern;
                    Matcher keyMatcher;
                    Pattern valuePattern;
                    Matcher valueMatcher;
                    String myNewValue = "";

                    // parsing flink dashboard data
                    Matcher flinkPattern = Pattern.compile("^org.apache.flink.*").matcher(mykey);
                    Matcher javaLangPattern = Pattern.compile("^java.(lang|nio):(type|name)=").matcher(mykey);
                    if (flinkPattern.find()) {
                        // Parsing key
                        keyPattern = Pattern.compile("(.*flink.*):");
                        keyMatcher = keyPattern.matcher(mykey);
                        if (keyMatcher.find()) {
                            //To replace "org.apache.flink.taskmanager.Status."
                            mykey = keyMatcher.group(1);
                            keyMatcher = Pattern.compile("org\\.apache\\.flink\\.taskmanager\\.Status\\.").matcher(mykey);
                            if (keyMatcher.find()){
                                mykey = keyMatcher.replaceAll("dash_");
                            }
                            // To replace "." in key
                            mykey = mykey.replaceAll("\\.","");
                        }

                        // Parsing value
                        valueMatcher = Pattern.compile("Value = (.*)\\]").matcher(myvalue.toString());
                        if (valueMatcher.find()) {
                            myNewValue = valueMatcher.group(1);
                        } else {
                            myNewValue = "NAN";
                        }
                        // Adding to the hash map list
                        myMetricI.put(mykey,myNewValue);

                    } else if (javaLangPattern.find()) {
                        // key with "name" and "type"
                        keyMatcher = Pattern.compile("name=(.*),type=(.*)$").matcher(mykey);
                        if (keyMatcher.find()) {
                            String mytmpkey = "";
                            for (int i = 1; i <= keyMatcher.groupCount(); i++) {
                                mytmpkey += keyMatcher.group(i);
                            }
                            mykey = mytmpkey.replaceAll("\\s","");
                        } else {
                            // Get key
                            keyMatcher = Pattern.compile(".*=(.*)$").matcher(mykey);
                            if (keyMatcher.find()) {
                                mykey = keyMatcher.group(1);
                            }
                        }
                        // Get value
                        valuePattern = Pattern.compile("\\[\\s*(.*)\\s=\\s(.*)\\]");
                        valueMatcher = valuePattern.matcher(myvalue.toString());
                        if (valueMatcher.find()) {
                            mykey = mykey + valueMatcher.group(1);
                            myNewValue = valueMatcher.group(2);

                            // To process composite data structure
                            valueMatcher = Pattern.compile("javax.management.openmbean.CompositeDataSupport").matcher(myvalue.toString());
                            if (valueMatcher.find()) {
                                Pattern pattern = Pattern.compile("(?<=\\b(init|max|used|committed)=)(\\d+)");
                                Matcher matcher = pattern.matcher(myvalue.toString());
                                while (matcher.find()) {
                                    myMetricI.put(mykey + "_" + matcher.group(1), matcher.group(2));
                                }
                            } else { myMetricI.put(mykey,myNewValue); }
                        }
                    }
                }
            }

            // Adding timestamp to header and data point
            String headers = "timestamp,";
            String dataPoints = loggingTimestamp + ",";

            if (getJvmHeader) {
                for (String i: myMetricI.keySet()) {
                    headers += i + ",";
                }
                // add "timestamp" header
                jvmLogger.info(headers);
                getJvmHeader = false;
            }
            for (String i: myMetricI.keySet()){
                dataPoints += myMetricI.get(i) + ",";
            }

            // Log the information finally
            jvmLogger.info(dataPoints);
        } catch (IOException | InstanceNotFoundException | ReflectionException e) {
            mainLogger.error("",e);
            System.exit(1);
            //e.printStackTrace();
        } catch (Throwable e) {
            mainLogger.error("",e);
            System.exit(1);
        }
    }

    public static List<HashMap<String,String>> getAvailableMetrics(MBeanServerConnection mbs){
        List<HashMap<String,String>> list = new ArrayList<>();
        Set<ObjectName> objectNames;
        try {
            objectNames = mbs.queryNames(null, null);
            for (ObjectName name : objectNames) {
                MBeanInfo info = mbs.getMBeanInfo(name);
                MBeanAttributeInfo[] attributes = info.getAttributes();
                // Get all/selected query with all the attributes
                for (MBeanAttributeInfo attribute : attributes) {
                    HashMap<String,String> tempMap = new HashMap<>();
                    tempMap.put(name.toString(),attribute.getName());
                    list.add(tempMap);
                }
            }
        } catch (IOException | InstanceNotFoundException | ReflectionException | IntrospectionException e) {
            throw new RuntimeException(e);
        }
        return list;
    }

    public static List getQueryParams(CommandLine opt)  {
        try {
            ObjectName objectName;
            if (opt.hasOption("all") || opt.hasOption("get-metric-list")) {
                objectName = null;
            } else {
                objectName = new ObjectName(opt.getOptionValue("query"));
            }
            String queryAttribute = opt.getOptionValue("query-attribute", null);
            return Arrays.asList((ObjectName)objectName, queryAttribute);
        } catch (MalformedObjectNameException e) {
            throw new RuntimeException(e);
        }
    }

    public static void getMetrics(MBeanServerConnection mbs, List queryParams, CommandLine opt) {
        // Initializing logging string
        String logStr = "";
        try {
            Set<ObjectName> objectNames = mbs.queryNames((ObjectName) queryParams.get(0), null);
            String queryAttribute = (String) queryParams.get(1);

            for (ObjectName name : objectNames) {
                MBeanInfo info = mbs.getMBeanInfo(name);

                MBeanAttributeInfo[] attributes = info.getAttributes();
                // Get all/selected query with all the attributes
                if (opt.hasOption("all") || queryAttribute == null) {
                    for (MBeanAttributeInfo attribute : attributes) {
//                        if (!(
////                                        name.toString().toLowerCase().contains("java.lang:type=Runtime".toLowerCase()) ||
////                                        name.toString().toLowerCase().contains("org.apache.logging.log4j2".toLowerCase()) ||
////                                        attribute.getName().toLowerCase().contains("LastGcInfo".toLowerCase())
//                         )) {
                        //logger.info(name + metricDelimiter + attribute.getName() + metricDelimiter + mbs.getAttributes(ObjectName.getInstance(name), new String[]{attribute.getName()}));
                        logStr += mbs.getAttributes(ObjectName.getInstance(name), new String[]{attribute.getName()}) + metricDelimiter;
                    }
                } else {
                    Arrays.stream(attributes).filter(x -> queryAttribute.equals(x.getName())).findAny().orElseThrow(new Supplier<Throwable>() {
                        @Override
                        public Throwable get() {
                            return new Throwable("Given attribute is not present/available");
                        }
                    });
                    //logStr += name + metricDelimiter + queryAttribute + metricDelimiter + mbs.getAttributes(ObjectName.getInstance(name), new String[]{queryAttribute});
                    logStr += mbs.getAttributes(ObjectName.getInstance(name), new String[]{queryAttribute}) + metricDelimiter;
                }
            }

            jvmLogger.info(logStr);

        } catch (IOException | IntrospectionException | InstanceNotFoundException | ReflectionException e) {
            mainLogger.error("",e);
            System.exit(1);
//            e.printStackTrace();
        } catch (Throwable e) {
            mainLogger.error("",e);
            System.exit(1);
//            throw new RuntimeException(e);
        }
    }

    public static void writeToFile(String str, String fileName, boolean append) throws IOException {
        BufferedWriter writer = new BufferedWriter(new FileWriter(fileName, append));
        writer.write(str);
        writer.newLine();
        writer.close();
    }

    public static void getMetricsList(MBeanServerConnection mbs, CommandLine opt) {

        // Initializing logging string
        String logStr = "";

        try {
            Set<ObjectName> objectNames = mbs.queryNames(null, null);

            for (ObjectName name : objectNames) {
                MBeanInfo info = mbs.getMBeanInfo(name);

                MBeanAttributeInfo[] attributes = info.getAttributes();
                // Get all/selected query with all the attributes
                for (MBeanAttributeInfo attribute : attributes) {
                    if (!( //filters
                            name.toString().toLowerCase().contains("java.lang:type=Runtime".toLowerCase()) ||
                                    name.toString().toLowerCase().contains("org.apache.logging.log4j2".toLowerCase()) ||
                                    attribute.getName().toLowerCase().contains("LastGcInfo".toLowerCase())
                    )) {
                        //logger.info(name + metricDelimiter + attribute.getName() + metricDelimiter + mbs.getAttributes(ObjectName.getInstance(name), new String[]{attribute.getName()}));
                        // java.lang:type=OperatingSystem$[CommittedVirtualMemorySize = 8359288832]
                        logStr += name + metricDelimiter + attribute.getName() + metricDelimiter + mbs.getAttributes(ObjectName.getInstance(name), new String[]{attribute.getName()});
                        logStr += "\r\n";
                    }
                }
            }

            String defaultFile = "metricList.log";
            if (!opt.hasOption("output-file")){
                System.out.println("No file name specified. Writing to file: " + defaultFile);
            }
            writeToFile(logStr, opt.getOptionValue("output-file",defaultFile),false);

        } catch (IOException | IntrospectionException | InstanceNotFoundException | ReflectionException e) {
            e.printStackTrace();
        } catch (Throwable e) {
            throw new RuntimeException(e);
        }
    }

    public static List<HashMap<String, String>> parseInputMetricFile(String file){

        List<HashMap<String,String>> metricLists = new ArrayList<>();

        try(BufferedReader br = new BufferedReader(new FileReader(file))) {
            for(String line; (line = br.readLine()) != null; ) {

                HashMap<String,String> mapObjectAttribute =new HashMap<>();

                // process the line.
                String[] abc = line.split(metricDelimiter);
                mapObjectAttribute.put(abc[0],abc[1]);
                metricLists.add(mapObjectAttribute);
            }

            // line is not visible here.
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return metricLists;
    }

    public static List<HashMap<String, String>> getMatchedMetric(List<HashMap<String,String>> inputQueryParams, List<HashMap<String,String>> availableMetricList){
        List<HashMap<String,String>> outList = new ArrayList<>();
        for (HashMap inputMetricMap: inputQueryParams) {
            String inputKey = (String) inputMetricMap.keySet().toArray()[0];
            String inputVal = (String) inputMetricMap.values().toArray()[0];
            HashMap<String,String> outHashMap = new HashMap<>();
            for (HashMap<String,String> availMetricMap: availableMetricList) {
                String availKey = availMetricMap.keySet().toArray()[0].toString();
                String availVal = availMetricMap.values().toArray()[0].toString();
                if (availKey.contains(inputKey) && availVal.contains(inputVal)){
                    outHashMap.put(availKey,availVal);
                    outList.add(outHashMap);
                    break;
                }
            }
        }
        return outList;
    }

    public static boolean extactMatchInList(String matchString, List<String> list){
//        Pattern pattern = Pattern.compile("\\b"+matchString+"\\b");
//        Matcher matcher = pattern.matcher()
        for (String s: list){
            if (s.equals(matchString)){
                return true;
            }
        }
        return false;
    }

    public static void jvmMetricExtractorRunner(CommandLine opt) {
        // Get MBeans server connection
        MBeanServerConnection mbs = MetricUtil.getMBeansServerConnection(opt);

        List<HashMap<String,String>> availableMetricList = getAvailableMetrics(mbs);

        // Get parameters to be queried
        if (opt.hasOption("input-query-file")) {

            // Get parameters from input file
            List<HashMap<String,String>> inputQueryParams = parseInputMetricFile(opt.getOptionValue("input-query-file","./inputMetricList.log"));
            List<HashMap<String,String>> inputQueryParamsMatched = getMatchedMetric(inputQueryParams, availableMetricList);

            while (true) {
                getMetricsFromInputFile(mbs, inputQueryParamsMatched, opt);
                try {
                    Thread.sleep(Long.parseLong(opt.getOptionValue("logging-interval", "5000")));
                } catch (InterruptedException e) {
                    throw new RuntimeException(e);
                }
            }
        } else {
            // Get query parameter when input file is not provided
            List queryParams = getQueryParams(opt);

            // Get metrics
            while (true) {
                getMetrics(mbs, queryParams, opt);
                try {
                    Thread.sleep(Long.parseLong(opt.getOptionValue("logging-interval", "5000")));
                } catch (InterruptedException e) {
                    throw new RuntimeException(e);
                }
            }
        }
    }

    public static void kafkaMetricExtractorRunner(CommandLine opt) {
        String mbeansNamePrefix = "kafka.server:type=BrokerTopicMetrics,name=*,topic=*";
        List<String> mbeansPropertyList = Arrays.asList(
                "BytesInPerSec", "MessagesInPerSec", "TotalProduceRequestsPerSec", "BytesOutPerSec", "MessagesOutPerSec"
        );
        List<String> mbeansPropertyAttributeList = Arrays.asList(
                "Count", "OneMinuteRate", "MeanRate"
        ); // FiveMinuteRate, FifteenMinuteRate

        String providedTopicAsInput = opt.getOptionValue("kafka-topic-list");
        List<String> kafkfTopicList = List.of(providedTopicAsInput.split(","));

        try {
            // Get MBeans server connection
            MBeanServerConnection mbeanServerConn = MetricUtil.getMBeansServerConnection(opt);

            // get all MBeans with the prefix "kafka.server:type=BrokerTopicMetrics,name="
            Set<ObjectInstance> mbeanInstances = mbeanServerConn.queryMBeans(
                    new ObjectName(mbeansNamePrefix), null);

            StringBuilder logHeaderLine = new StringBuilder();

//            KafkaEventLatencyCalculator latencyCalculator = new KafkaEventLatencyCalculator(
//                    opt.getOptionValue("kafka-bootstrap-server", "localhost:9092"),
//                    opt.getOptionValue("kafka-topic-list"),"test",
//                    opt.getOptionValue("logging-interval"),
//                    opt.getOptionValue("regex-pattern")
//            );

            KafkaEventLatencyCalculator latencyCalculator = new KafkaEventLatencyCalculator(
                    opt.getOptionValue("kafka-bootstrap-server", "localhost:9092"),
                    opt.getOptionValue("kafka-topic-list"),"test",
                    opt.getOptionValue("logging-interval")
            );

            boolean printHeader = true;
            boolean printWaitMsg = true;
            boolean printArriveMsg = true;
            while (true) {
                // Throughput information using jmx extension
                //------------------------------------------------------------------------------------------------------
                StringBuilder logLine = new StringBuilder();
                // iterate over the MBeans and extract the metric data for "BrokerTopicMetrics"
                for (ObjectInstance mbeanInstance : mbeanInstances) {
                    String mbeanInstancePropertyName = mbeanInstance.getObjectName().getKeyPropertyList().get("name");
                    String topicName = mbeanInstance.getObjectName().getKeyPropertyList().get("topic");
                    if (mbeansPropertyList.contains(mbeanInstancePropertyName) && MetricUtil.extactMatchInList(topicName, kafkfTopicList)) {
                        MBeanInfo mbeanInfo = mbeanServerConn.getMBeanInfo(mbeanInstance.getObjectName());
                        MBeanAttributeInfo[] attributeInfos = mbeanInfo.getAttributes();
                        for (MBeanAttributeInfo attributeInfo : attributeInfos) {
                            String attributeName = attributeInfo.getName();
                            if (mbeansPropertyAttributeList.contains(attributeName)) {
                                Object attributeValue = mbeanServerConn.getAttribute(mbeanInstance.getObjectName(), attributeName);
                                if (printHeader) {
                                    logHeaderLine.append(
                                            mbeanInstance.getObjectName().toString()
                                                    .replaceAll(".*name=", "")
                                                    .replaceAll(",topic=", "_") +
                                                    "_" + attributeName + ","
                                    );
                                }
                                logLine.append(String.format("%.2f", Double.parseDouble(attributeValue.toString()))).append(",");
                            }
                        }
                    }
                }
                if (logHeaderLine.toString().equals("") || logLine.toString().equals("")) {
                    if (printWaitMsg) {
                        mainLogger.info("Waiting for elements to arrive.");
                        printWaitMsg = false;
                    }
                    mbeanInstances = mbeanServerConn.queryMBeans(
                            new ObjectName(mbeansNamePrefix), null);
                } else {
                    if (printArriveMsg) {
                        mainLogger.info("Thank goodness events came to save us finally.");
                        printArriveMsg = false;
                    }
                    if (printHeader) {
                        throughputLatencyLogger.info("timestamp," + logHeaderLine + "latency_ms");
                        printHeader = false;
                    }
                    long nowTimestamp = System.currentTimeMillis();

                    String latency = latencyCalculator.getKafkaEventLatency();
                    if (latency.equals("")) {
                        latency="0";
                    }

                    throughputLatencyLogger.info(nowTimestamp + "," + logLine + latency);
                }
                Thread.sleep(Long.parseLong(opt.getOptionValue("logging-interval")));
            }
        } catch (Exception e) {
            mainLogger.error("",e);
        }
    }

}
