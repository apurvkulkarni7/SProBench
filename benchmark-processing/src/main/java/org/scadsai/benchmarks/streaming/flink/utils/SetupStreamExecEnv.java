package org.scadsai.benchmarks.streaming.flink.utils;

import org.apache.commons.cli.CommandLine;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

import static org.scadsai.benchmarks.streaming.flink.Main.MAIN_LOGGER;

public class SetupStreamExecEnv {
    private final int parallelism;

    public SetupStreamExecEnv(CommandLine opt) {
        this.parallelism = Integer.parseInt(opt.getOptionValue("parallelism", "1"));
    }

    public int getParallelism() {
        return parallelism;
    }

    public StreamExecutionEnvironment build() {
        // Initializing execution environment --------------------------------------------------------------------------
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // Set parallelism ---------------------------------------------------------------------------------------------
        if (this.getParallelism() == 0) {
            // Default parallelism is the total number of TaskManagers slots (16 for this machine)
            int defaultParallelism = env.getParallelism();
            MAIN_LOGGER.info("Using default parallelism: {}", defaultParallelism);
            env.setParallelism(defaultParallelism);
        } else {
            env.setParallelism(getParallelism());
        }

        // Set checkpointing properties --------------------------------------------------------------------------------
        // start a checkpoint every 10000 ms
//        env.enableCheckpointing(10000);

//        // advanced options:
//        set mode to exactly-once (this is the default)
//        env.getCheckpointConfig().setCheckpointingMode(CheckpointingMode.EXACTLY_ONCE);
//
//        // make sure 500 ms of progress happen between checkpoints
//        env.getCheckpointConfig().setMinPauseBetweenCheckpoints(500);
//
//        // checkpoints have to complete within one minute, or are discarded
//        env.getCheckpointConfig().setCheckpointTimeout(60000);
//
//        // only two consecutive checkpoint failures are tolerated
//        env.getCheckpointConfig().setTolerableCheckpointFailureNumber(2);
//
//        // allow only one checkpoint to be in progress at the same time
//        env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
//
//        // enable externalized checkpoints which are retained
//        // after job cancellation
//        env.getCheckpointConfig().enableExternalizedCheckpoints(ExternalizedCheckpointCleanup.RETAIN_ON_CANCELLATION);
//
//        // enables the unaligned checkpoints
//        env.getCheckpointConfig().enableUnalignedCheckpoints();
//
//        // sets the checkpoint storage where checkpoint snapshots will be written
//        env.getCheckpointConfig().setCheckpointStorage("hdfs:///my/checkpoint/dir");
//        env.getCheckpointConfig().setCheckpointStorage("file:///home/apurv/my_disk/projects/stream-processing-flink/web-analytics");
//
//        // enable checkpointing with finished tasks
//        Configuration config = new Configuration();
//        config.set(ExecutionCheckpointingOptions.ENABLE_CHECKPOINTS_AFTER_TASKS_FINISH, true);
//        env.configure(config);

        //StreamProcessing.LOGGER.info(env.getConfiguration().toString());

        return env;
    }
}
