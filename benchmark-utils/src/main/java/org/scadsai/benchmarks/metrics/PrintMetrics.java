package org.scadsai.benchmarks.metrics;

import org.apache.commons.cli.CommandLine;
import org.scadsai.benchmarks.metrics.util.CliParamGenerator;

import javax.management.MBeanServerConnection;

import static org.scadsai.benchmarks.metrics.util.MetricUtil.getMBeansServerConnection;
import static org.scadsai.benchmarks.metrics.util.MetricUtil.getMetricsList;

public class PrintMetrics {
    public static void main(String[] args) {
        // Get cli argument and parse them
        CommandLine opt = new CliParamGenerator(args).build();

        // Get MBeans server connection
        MBeanServerConnection mbs = getMBeansServerConnection(opt);

        // Print metric list
        getMetricsList(mbs,opt);
    }
}
