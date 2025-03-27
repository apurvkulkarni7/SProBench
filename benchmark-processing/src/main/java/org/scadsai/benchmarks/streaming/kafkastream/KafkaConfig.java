package org.scadsai.benchmarks.streaming.kafkastream;

import java.util.List;

public class KafkaConfig {
    private int cpu;
    private int memory_gb;
    private List<Topic> source_topics;
    private List<Topic> sink_topics;
    private String stateful_directory;

    public int getCpu() {
        return cpu;
    }

    public void setCpu(int cpu) {
        this.cpu = cpu;
    }

    public int getMemory_gb() {
        return memory_gb;
    }

    public void setMemory_gb(int memory_gb) {
        this.memory_gb = memory_gb;
    }

    public List<Topic> getSource_topics() {
        return source_topics;
    }

    public void setSource_topics(List<Topic> source_topics) {
        this.source_topics = source_topics;
    }

    public List<Topic> getSink_topics() {
        return sink_topics;
    }

    public void setSink_topics(List<Topic> sink_topics) {
        this.sink_topics = sink_topics;
    }

    public String getStateful_directory() { return stateful_directory; }

    public void setStateful_directory(String stateful_directory) {
        this.stateful_directory = stateful_directory;
    }

    public static class Topic {
        private String name;
        private int num_partition;

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }

        public int getNum_partition() {
            return num_partition;
        }

        public void setNum_partition(int num_partition) {
            this.num_partition = num_partition;
        }
    }
}
