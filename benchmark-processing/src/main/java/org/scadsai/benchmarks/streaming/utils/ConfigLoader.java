package org.scadsai.benchmarks.streaming.utils;

import org.yaml.snakeyaml.Yaml;

import java.io.FileInputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

public class ConfigLoader {

    private String file;

    public ConfigLoader(String file) {
        this.file = file;
    }

    public BenchmarkConfig parser() {
        Yaml yaml = new Yaml();
        Map<String, Object> config;
        System.out.println(this.file + " is loading...");
        try {
            FileInputStream inputStream = new FileInputStream(this.file);
            config = yaml.load(inputStream);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        BenchmarkConfig myConfig = yamlParser(config);
        return myConfig;
    }

    public BenchmarkConfig yamlParser(Map<String, Object> config) {
        BenchmarkConfig parsedConfig = new BenchmarkConfig();
        parsedConfig.setDebugMode(Boolean.parseBoolean(config.get("debug_mode").toString()));
        parsedConfig.setLoggingLevel((int) config.get("logging_level"));
        parsedConfig.setBenchmarkRuntimeMin((int) config.get("benchmark_runtime_min"));
        parsedConfig.setMetricLoggingIntervalSec((int) config.get("metric_logging_interval_sec"));
        parsedConfig.setRunsPerConfiguration((int) config.get("runs_per_configuration"));
        parsedConfig.setTotalWorkloadHz((int) config.get("total_workload_hz"));
        parsedConfig.setTmpDir((String) config.get("tmp_dir"));
        parsedConfig.setGenerator((Map<String, Object>) config.get("generator"));
        parsedConfig.setStreamProcessor((Map<String, Object>) config.get("stream_processor"));
        parsedConfig.setNumCpusSpare((int) config.get("num_cpus_spare"));
        parsedConfig.setMemNodeSpare((int) config.get("mem_node_spare"));
        parsedConfig.setKafka((Map<String, Object>) config.get("kafka"));
        return parsedConfig;
    }

    public class BenchmarkConfig {
        private boolean debugMode;
        private int loggingLevel;
        private int benchmarkRuntimeMin;
        private int metricLoggingIntervalSec;
        private int runsPerConfiguration;
        private int totalWorkloadHz;
        private String tmpDir;
        private Generator generator = new Generator();
        private StreamProcessor streamProcessor = new StreamProcessor();
        private int numCpusSpare;
        private int memNodeSpare;
        private Kafka kafka = new Kafka();
        //private Framework frameworks = new Framework();
        //private List<String> customModulePath;
        //private SlurmSetup slurmSetup = new SlurmSetup();

        public boolean isDebugMode() {
            return debugMode;
        }

        public void setDebugMode(boolean debugMode) {
            this.debugMode = debugMode;
        }

        public int getLoggingLevel() {
            return loggingLevel;
        }

        public void setLoggingLevel(int loggingLevel) {
            this.loggingLevel = loggingLevel;
        }

        public int getBenchmarkRuntimeMin() {
            return benchmarkRuntimeMin;
        }

        public void setBenchmarkRuntimeMin(int benchmarkRuntimeMin) {
            this.benchmarkRuntimeMin = benchmarkRuntimeMin;
        }

        public int getMetricLoggingIntervalSec() {
            return metricLoggingIntervalSec;
        }

        public void setMetricLoggingIntervalSec(int metricLoggingIntervalSec) {
            this.metricLoggingIntervalSec = metricLoggingIntervalSec;
        }

        public int getRunsPerConfiguration() {
            return runsPerConfiguration;
        }

        public void setRunsPerConfiguration(int runsPerConfiguration) {
            this.runsPerConfiguration = runsPerConfiguration;
        }

        public int getTotalWorkloadHz() {
            return totalWorkloadHz;
        }

        public void setTotalWorkloadHz(int totalWorkloadHz) {
            this.totalWorkloadHz = totalWorkloadHz;
        }

        public String getTmpDir() {
            return tmpDir;
        }

        public void setTmpDir(String tmpDir) {
            this.tmpDir = tmpDir;
        }

        public Generator getGenerator() {
            return generator;
        }

        public void setGenerator(Map<String, Object> generatorRaw) {
            this.generator.setType(generatorRaw.get("type").toString());
            this.generator.setLoadHz((int) generatorRaw.get("load_hz"));
            this.generator.setThreadsPerCpuNum((int) generatorRaw.get("threads_per_cpu_num"));
            this.generator.setMemoryGb((int) generatorRaw.get("memory_gb"));
            this.generator.setRecordSizeBytes((int) generatorRaw.get("record_size_bytes"));
            this.generator.setOnlyDataGenerator(Boolean.parseBoolean(generatorRaw.get("only_data_generator").toString()));
            this.generator.setCpu(Integer.parseInt(generatorRaw.get("cpu").toString()));
        }

        public StreamProcessor getStreamProcessor() {
            return streamProcessor;
        }

        public void setStreamProcessor(Map<String, Object> streamProcessorRaw) {
            this.streamProcessor.setProcessingType(streamProcessorRaw.get("processing_type").toString());
            this.streamProcessor.setFramework(((ArrayList) streamProcessorRaw.get("framework")).get(0).toString());
            this.streamProcessor.setMaster((Map<String, Object>) streamProcessorRaw.get("master"));
            this.streamProcessor.setWorker((Map<String, Object>) streamProcessorRaw.get("worker"));
            this.streamProcessor.setStateDir(streamProcessorRaw.get("stateful_dir").toString());
            this.streamProcessor.setWindowLength(Long.parseLong(streamProcessorRaw.get("window_length_ms").toString()));
            this.streamProcessor.setWindowAdvanceMs(Long.parseLong(streamProcessorRaw.get("window_advance_ms").toString()));
        }

        public int getNumCpusSpare() {
            return numCpusSpare;
        }

        public void setNumCpusSpare(int numCpusSpare) {
            this.numCpusSpare = numCpusSpare;
        }

        public int getMemNodeSpare() {
            return memNodeSpare;
        }

        public void setMemNodeSpare(int memNodeSpare) {
            this.memNodeSpare = memNodeSpare;
        }

        public Kafka getKafka() {
            return this.kafka;
        }

        public void setKafka(Map<String, Object> kafkaRaw) {
            this.kafka.setCpu((int) kafkaRaw.get("cpu"));
            this.kafka.setMemoryGb((int) kafkaRaw.get("memory_gb"));
            this.kafka.setSourceTopics((List) kafkaRaw.get("source_topics"));
            this.kafka.setSinkTopics((List) kafkaRaw.get("sink_topics"));
        }

        @Override
        public String toString() {
            return "Config{" +
                    "debugMode=" + debugMode +
                    ", loggingLevel=" + loggingLevel +
                    ", benchmarkRuntimeMin=" + benchmarkRuntimeMin +
                    ", metricLoggingIntervalSec=" + metricLoggingIntervalSec +
                    ", runsPerConfiguration=" + runsPerConfiguration +
                    ", totalWorkloadHz=" + totalWorkloadHz +
                    ", tmpDir='" + tmpDir + '\'' +
                    ", generator=" + generator +
                    ", streamProcessor=" + streamProcessor +
                    ", numCpusSpare=" + numCpusSpare +
                    ", memNodeSpare=" + memNodeSpare +
                    ", kafka=" + kafka +
                    '}';
        }
    }

    public class Generator {
        private String type;
        private int loadHz;
        private int cpu;
        private int threadsPerCpuNum;
        private int memoryGb;
        private int recordSizeBytes;
        private boolean onlyDataGenerator;

        // Getters and setters
        public String getType() {
            return type;
        }

        public void setType(String type) {
            this.type = type;
        }

        public int getLoadHz() {
            return loadHz;
        }

        public void setLoadHz(int loadHz) {
            this.loadHz = loadHz;
        }

        public int getCpu() {
            return cpu;
        }

        public void setCpu(int cpu) {
            this.cpu = cpu;
        }

        public int getThreadsPerCpuNum() {
            return threadsPerCpuNum;
        }

        public void setThreadsPerCpuNum(int threadsPerCpuNum) {
            this.threadsPerCpuNum = threadsPerCpuNum;
        }

        public int getMemoryGb() {
            return memoryGb;
        }

        public void setMemoryGb(int memoryGb) {
            this.memoryGb = memoryGb;
        }

        public int getRecordSizeBytes() {
            return recordSizeBytes;
        }

        public void setRecordSizeBytes(int recordSizeBytes) {
            this.recordSizeBytes = recordSizeBytes;
        }

        public boolean isOnlyDataGenerator() {
            return onlyDataGenerator;
        }

        public void setOnlyDataGenerator(boolean onlyDataGenerator) {
            this.onlyDataGenerator = onlyDataGenerator;
        }

        @Override
        public String toString() {
            return "Generator{" +
                    "type='" + type + '\'' +
                    ", loadHz=" + loadHz +
                    ", cpu=" + cpu +
                    ", threadsPerCpuNum=" + threadsPerCpuNum +
                    ", memoryGb=" + memoryGb +
                    ", recordSizeBytes=" + recordSizeBytes +
                    ", onlyDataGenerator=" + onlyDataGenerator +
                    '}';
        }
    }

    public class StreamProcessor {
        private String processingType;
        private String framework;
        private String stateDir = "/tmp";
        private Master master = new Master();
        private Worker worker = new Worker();
        private long windowLengthMs;
        private long windowAdvanceMs;

        // Getters and setters
        public String getProcessingType() {
            return processingType;
        }

        public void setProcessingType(String processingType) {
            this.processingType = processingType;
        }

        public String getFramework() {
            return framework;
        }

        public void setFramework(String framework) {
            this.framework = framework;
        }

        public Master getMaster() {
            return master;
        }

        public void setMaster(Map<String, Object> masterRaw) {
            this.master.setCpu((int) masterRaw.get("cpu"));
            this.master.setMemoryGb((int) masterRaw.get("memory_gb"));
        }

        public Worker getWorker() {
            return worker;
        }

        public void setWorker(Map<String, Object> workerRaw) {
            this.worker.setInstances((int) workerRaw.get("instances"));
            this.worker.setMemoryGb((int) workerRaw.get("memory_gb"));
            this.worker.setParallelism((int) workerRaw.get("parallelism"));
        }

        public void setStateDir(String stateDir) {
            this.stateDir = stateDir;
        }

        public String getStateDir() {
            return this.stateDir;
        }

        @Override
        public String toString() {
            return "StreamProcessor{" +
                    "processingType='" + processingType + '\'' +
                    ", framework='" + framework + '\'' +
                    ", master=" + master +
                    ", worker=" + worker +
                    ", stateDir=" + stateDir +
                    '}';
        }

        public void setWindowLength(long windowLengthMs) {
            this.windowLengthMs = windowLengthMs;
        }

        public long getWindowLengthMs() {
            return this.windowLengthMs;
        }

        public void setWindowAdvanceMs(long windowAdvanceMs) {
            this.windowAdvanceMs = windowAdvanceMs;
        }

        public long getWindowAdvanceMs() {
            return this.windowAdvanceMs;
        }
    }

    public class Master {
        private int cpu;
        private int memoryGb;

        // Getters and setters
        public int getCpu() {
            return cpu;
        }

        public void setCpu(int cpu) {
            this.cpu = cpu;
        }

        public int getMemoryGb() {
            return memoryGb;
        }

        public void setMemoryGb(int memoryGb) {
            this.memoryGb = memoryGb;
        }

        @Override
        public String toString() {
            return "Master{" +
                    "cpu='" + cpu + '\'' +
                    ", memoryGB='" + memoryGb + '\'' +
                    '}';
        }
    }

    public class Worker {
        private int instances;
        private int memoryGb;
        private int parallelism;

        // Getters and setters
        public int getInstances() {
            return instances;
        }

        public void setInstances(int instances) {
            this.instances = instances;
        }

        public int getMemoryGb() {
            return memoryGb;
        }

        public void setMemoryGb(int memoryGb) {
            this.memoryGb = memoryGb;
        }

        public int getParallelism() {
            return parallelism;
        }

        public void setParallelism(int parallelism) {
            this.parallelism = parallelism;
        }

        @Override
        public String toString() {
            return "Worker{" +
                    "instances='" + instances + '\'' +
                    ", parallelism='" + parallelism + '\'' +
                    ", memoryGB='" + memoryGb + '\'' +
                    '}';
        }
    }

    public class Kafka {
        private int cpu;
        private int memoryGb;
        private List<SourceTopic> sourceTopics = new ArrayList<>();
        private List<SinkTopic> sinkTopics = new ArrayList<>();
        private String sourceBootstrapServer;
        private String sinkBootstrapServer;

        // Getters and setters
        public int getCpu() {
            return cpu;
        }

        public void setCpu(int cpu) {
            this.cpu = cpu;
        }

        public int getMemoryGb() {
            return memoryGb;
        }

        public void setMemoryGb(int memoryGb) {
            this.memoryGb = memoryGb;
        }

        public List<SourceTopic> getSourceTopics() {
            return sourceTopics;
        }

        public void setSourceTopics(List<Map<String, Object>> sourceTopicsRaw) {
            for (Map<String, Object> sourceTopic_i : sourceTopicsRaw) {
                SourceTopic sourceTopic = new SourceTopic();
                sourceTopic.setName(sourceTopic_i.get("name").toString());
                sourceTopic.setNumPartition(sourceTopic_i.get("num_partition").toString());
                this.sourceTopics.add(sourceTopic);
            }
        }

        public List<SinkTopic> getSinkTopics() {
            return sinkTopics;
        }

        public void setSinkTopics(List<Map<String, Object>> sinkTopicsRaw) {
            for (Map<String, Object> sinkTopic_i : sinkTopicsRaw) {
                SinkTopic sinkTopic = new SinkTopic();
                sinkTopic.setName(sinkTopic_i.get("name").toString());
                sinkTopic.setNumPartition(sinkTopic_i.get("num_partition").toString());
                this.sinkTopics.add(sinkTopic);
            }
        }

        public <T extends Topic> String getTopicNames(List<T> topics) {
            return topics.stream()
                    .map(Topic::getName)
                    .collect(Collectors.joining(","));
        }

        public String getSourceTopicNames() {
            return getTopicNames(getSourceTopics());
        }

        public String getSinkTopicNames() {
            return getTopicNames(getSinkTopics());
        }

        public void setSourceBootstrapServer(String sourceBootstrapServers) {
            this.sourceBootstrapServer = sourceBootstrapServers;
        }

        public String getSourceBootstrapServer() {
            return this.sourceBootstrapServer;
        }

        public String getSinkBootstrapServer() {
            return sinkBootstrapServer;
        }

        public void setSinkBootstrapServer(String sinkBootstrapServer) {
            this.sinkBootstrapServer = sinkBootstrapServer;
        }

        @Override
        public String toString() {
            return "Kafka{" +
                    "cpu='" + cpu + '\'' +
                    ", memoryGb='" + memoryGb + '\'' +
                    ", SourceTopics='" + sourceTopics + '\'' +
                    ", SinkTopics='" + sinkTopics + '\'' +
                    ", SourceBootstrapServer='" + sourceBootstrapServer + '\'' +
                    ", SinkBootstrapServer='" + sinkBootstrapServer + '\'' +
                    '}';
        }
    }

    public interface Topic {
        String getName();

        void setName(String name);

        String getNumPartition();

        void setNumPartition(String numPartition);
    }

    public abstract class AbstractTopic implements Topic {
        private String name;
        private String numPartition;

        @Override
        public String getName() {
            return name;
        }

        @Override
        public void setName(String name) {
            this.name = name;
        }

        @Override
        public String getNumPartition() {
            return numPartition;
        }

        @Override
        public void setNumPartition(String numPartition) {
            this.numPartition = numPartition;
        }

        @Override
        public String toString() {
            return getClass().getSimpleName() + "{" +
                    "name='" + name + '\'' +
                    ", numPartition='" + numPartition + '\'' +
                    '}';
        }
    }

    public class SourceTopic extends AbstractTopic {
    }

    public class SinkTopic extends AbstractTopic {
    }

}