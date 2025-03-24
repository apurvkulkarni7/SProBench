#!/bin/bash

set -o pipefail
set -o errtrace
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

source ${BENCHMARK_DIR}/utils/auxiliary_processes.sh

trap_ctrlc() {
  run "STOP_LOAD"
  run "STOP_FLINK"
  run "STOP_KAFKA"
  run "STOP_JMX_COLLECTOR"
}

trap trap_ctrlc SIGINT SIGTERM

check_var BENCHMARK_DIR

run() {
  OPERATION=$1
  if [[ "START_KAFKA" == "$OPERATION" ]]; then
    #############################################################################
    # Kafka
    #############################################################################
    # start on every worker
    if [[ "$KAFKA_ARCH" == "1" ]] || [[ $SPB_SYSTEM == "localmachine" ]] ; then
      source ${BENCHMARK_DIR}/utils/kafka_utils/kafka_cluster_setup.sh "${KAFKA_SOURCE_HOST}" "${KAFKA_CONF_DIR}" "${LOG_DIR_RUN_LOG_KAFKA}"
      LEADER_WORKER="${KAFKA_SOURCE_HOST}"
    elif [[ "$KAFKA_ARCH" == "2" ]]; then
      for WORKER_i in $FLINK_WORKERS; do
        ${BENCHMARK_DIR}/utils/kafka_utils/kafka_cluster_setup.sh "${WORKER_i}" "${KAFKA_CONF_DIR}" "${LOG_DIR_RUN_LOG_KAFKA}"
        WORKERS=($FLINK_WORKERS)
        LEADER_WORKER=${WORKERS[0]}
      done
    fi
    sleep 5s
    CHECK_INTERVAL_SEC="60"
    monitor_kafka_broker "${KAFKA_SOURCE_HOST}" "${SLURM_JOBID}"  "${BENCHMARK_RUNTIME_SEC}" "${CHECK_INTERVAL_SEC}" "${LOG_DIR_RUN_LOG}/STATUS" &
    create_or_update_kafka_topic "${LEADER_WORKER}:9092" "${KAFKA_SOURCE_PARTITION_NUM}" "${KAFKA_SOURCE_TOPICS}"
    
    if [[ "${FRAMEWORK}" != "GENERATOR" ]]; then
      create_or_update_kafka_topic "${LEADER_WORKER}:9092" "${KAFKA_SINK_PARTITION_NUM}" "${KAFKA_SINK_TOPICS}"
    fi

  elif [[ "STOP_KAFKA" == "$OPERATION" ]]; then
    stop_if_needed kafka\.Kafka Kafka
    safe_remove_recursive "$KAFKA_LOG_DIR"
  #############################################################################
  # Flink
  #############################################################################
  elif [[ "START_FLINK" == "$OPERATION" ]]; then
    $FLINK_HOME/bin/start-cluster.sh
    sleep 5
    if is_hpc; then
      logger_info "To get Flink gui on local machine, run: ssh -L 8081:$FLINK_MASTER:8081 <hostname-login>"
    fi
  elif [[ "STOP_FLINK" == "$OPERATION" ]]; then
    if [[ "x$FLINK_HOME" != "x" ]]; then
      $FLINK_HOME/bin/stop-cluster.sh
    fi
  #############################################################################
  # Processing - Flink
  #############################################################################
  elif [[ "START_FLINK_PROCESSING" == "$OPERATION" ]]; then
    FLINK_APP_OPTS="--parallelism ${FLINK_PARALLELISM} --source-type kafka --source-kafka-topic ${KAFKA_SOURCE_TOPICS} --source-bootstrap-server ${KAFKA_SOURCE_BOOTSTRAP_SERVER} --sink-type kafka --sink-kafka-topic ${KAFKA_SINK_TOPICS} --sink-bootstrap-server ${KAFKA_SINK_BOOTSTRAP_SERVER} --processing-type ${PROCESSING_TYPE}"

    "$FLINK_HOME/bin/flink" run "$BENCHMARK_DIR/benchmark-processing/target/benchmark-processing-1.0.jar" $FLINK_APP_OPTS > "$LOG_DIR_RUN_LOG_FLINK/flink.log" 2>&1 &
    sleep 10
    logger_info "Flink processing started"
  elif [[ "STOP_FLINK_PROCESSING" == "$OPERATION" ]]; then
    FLINK_ID=$(
      "$FLINK_HOME/bin/flink" list | grep 'Flink Streaming Job' | awk '{print $4}'
      true
    )
    if [[ "$FLINK_ID" == "" ]]; then
      logger_info "Could not find streaming job to kill"
    else
      "$FLINK_HOME/bin/flink" stop $FLINK_ID >> "$LOG_DIR_RUN_LOG_FLINK/flink.log" 2>&1
      logger_info "Stopped Flink processing."
      sleep 3
    fi
  elif [[ "START_LOAD" == "$OPERATION" ]]; then
    #############################################################################
    # Generator
    #############################################################################
    GENERATOR_OPT="--kafka-topic ${KAFKA_SOURCE_TOPICS} --bootstrap-server $KAFKA_SOURCE_BOOTSTRAP_SERVER"
    GENERATOR_OPT="$GENERATOR_OPT --loadHz ${GENERATOR_LOAD_PER_GENERATOR_HZ} --run-time-min ${BENCHMARK_RUNTIME_MIN}"
    GENERATOR_OPT="$GENERATOR_OPT --number-of-sensors ${NUM_CPU_WORKERS} --thread-count ${GENERATOR_THREAD_PER_CPU_NUM}"
    GENERATOR_OPT="$GENERATOR_OPT --producer-properties-file ${KAFKA_CONFIG_PRODUCER_PROP_FILE}"
    GENERATOR_OPT="$GENERATOR_OPT --logging-interval-sec $METRIC_LOGGING_INTERVAL_SEC --record-size $GENERATOR_RECORD_SIZE_B"

    if [[ "$ONLY_DATA_GENERATOR" == "True" ]]; then
      GENERATOR_OPT="$GENERATOR_OPT --only-generate-data"
    fi

    STARTING_CPUID=0
    ENDING_CPUID=$GENERATOR_CPU_NUM
    for (( GENERATOR_i=0; GENERATOR_i<"$GENERATOR_NUM"; GENERATOR_i++ )); do
      
      GENERATOR_CPU_ID="$(get_cpus ${STARTING_CPUID} ${ENDING_CPUID})"
      
      if ! is_hpc; then
        GEN_WRAPPER=${JAVA}
      else
        GEN_WRAPPER="numactl --physcpubind=${GENERATOR_CPU_ID} ${JAVA}"
      fi

      ${GEN_WRAPPER} \
        -XX:ActiveProcessorCount=${GENERATOR_CPU_NUM} -XX:ParallelGCThreads=1 -Xmx${MEM_GENERATOR} -XX:+HeapDumpOnOutOfMemoryError \
        -DlogFile="${LOG_DIR_RUN_LOG_GENERATOR}/generator_${GENERATOR_i}.log" \
        -cp "$BENCHMARK_DIR/benchmark-generator/target/benchmark-generator-1.0.jar" \
        org.scadsai.benchmarks.streaming.generator.GeneratorMain \
        $GENERATOR_OPT > "$LOG_DIR_RUN_LOG_GENERATOR/generator_$GENERATOR_i.out" 2>&1 &
      
      GEN_PID="$!"
      logger_info "Started Load Generator (pid=${GEN_PID}) with load ${GENERATOR_LOAD_PER_GENERATOR_HZ} Hz."

      STARTING_CPUID=$((GENERATOR_i+GENERATOR_CPU_NUM))
      ENDING_CPUID=$((STARTING_CPUID+GENERATOR_CPU_NUM))
    done
  elif [[ "STOP_LOAD" == "$OPERATION" ]]; then
    stop_if_needed GeneratorMain GeneratorMain
  elif [[ "START_JMX_COLLECTOR" == "$OPERATION" ]]; then
    #############################################################################
    # JMX Utilities
    #############################################################################
    # Running jmx on master node
    run_jmx_collector "${FLINK_MASTER}" "JVMMetricExtractor" \
      "StandaloneSessionClusterEntrypoint" "${FLINK_MASTER}_master" 
  
    # Running jmx on worker nodes
    for WORKER_i in $FLINK_WORKERS; do
      run_jmx_collector "${WORKER_i}" "JVMMetricExtractor" \
        "TaskManagerRunner" "${WORKER_i}_worker"
    done
  elif [[ "START_JMX_KAFKA_COLLECTOR" == "$OPERATION" ]]; then
    local kafka_topic=$2
    run_jmx_collector "${KAFKA_SOURCE_HOST}" "KafkaMetricExtractor" "Kafka" "${kafka_topic}"
  elif [[ "STOP_JMX_COLLECTOR" == "$OPERATION" ]]; then
    # Stopping JVM metric extractor on master node
    pid_files="$(find ${LOG_DIR_RUN_LOG_JMX} -name "*${FLINK_MASTER}*.pid" -type f)"
    for pid_i in $pid_files; do
      logger_info "Killing process: $(basename ${pid_i})"
      if [[ $SPB_SYSTEM =~ (slurm*) ]]; then
        run_remote_cmd ${FLINK_MASTER} "kill $(cat ${pid_i})"
      else
        kill $(cat ${pid_i})
      fi
    done

    # Stopping JMX collectors on worker nodes
    for host in $FLINK_WORKERS; do
      pid_files="$(find ${LOG_DIR_RUN_LOG_JMX} -name "*${host}*.pid" -type f)"
      for pid_i in $pid_files; do
        logger_info "Killing process: $(basename ${pid_i})"
        if [[ $SPB_SYSTEM =~ (slurm*) ]]; then
          run_remote_cmd ${host} "kill $(cat ${pid_i}) > /dev/null 2>&1"
        else
          kill $(cat ${pid_i}) > /dev/null 2>&1
        fi
      done
    done
  #############################################################################
  # Workflow - Generator testing
  #############################################################################
  elif [[ "GENERATOR_TEST_START" == "$OPERATION" ]]; then
    if [[ "$ONLY_DATA_GENERATOR" == "True" ]]; then
      run "START_LOAD"
    else
      run "START_KAFKA"
      sleep 5s
      run "START_LOAD"
      run "START_JMX_KAFKA_COLLECTOR" "eventsIn"
    fi
    logger_info "Running the data generator for $BENCHMARK_RUNTIME_MIN minutes."
    sleep "${BENCHMARK_RUNTIME_MIN}m"
    logger_info "Benchmark completed running for $BENCHMARK_RUNTIME_MIN minutes."
    sleep 20s
    if [[ "$ONLY_DATA_GENERATOR" != "True" ]]; then
      run "STOP_KAFKA"
    fi
  #############################################################################
  # Workflow - Flink
  #############################################################################
  elif [[ "FLINK_TEST_START" == "$OPERATION" ]]; then
    run "START_KAFKA"
    run "START_FLINK"
    sleep 5s
    run "START_JMX_COLLECTOR"
    run "START_FLINK_PROCESSING"
    run "START_LOAD"
    run "START_JMX_KAFKA_COLLECTOR" "eventsIn"
    run "START_JMX_KAFKA_COLLECTOR" "eventsOut"
    $JAVA_HOME/bin/jps > $LOG_DIR_RUN_LOG/running_java_proceses
    logger_info "Running the benchmark for $BENCHMARK_RUNTIME_MIN minutes."
    sleep "${BENCHMARK_RUNTIME_MIN}m"
    logger_info "Completed running benchmark for $BENCHMARK_RUNTIME_MIN minutes."
    echo "==" >> $LOG_DIR_RUN_LOG/running_java_proceses
    $JAVA_HOME/bin/jps >> $LOG_DIR_RUN_LOG/running_java_proceses
    #run "STOP_FLINK_PROCESSING"
    run "STOP_FLINK"
    #run "STOP_JMX_COLLECTOR"
    run "STOP_KAFKA"
  elif [[ "FLINK_TEST_STOP" == "$OPERATION" ]]; then
    run "STOP_FLINK_PROCESSING"
    run "STOP_FLINK"
    run "STOP_JMX_COLLECTOR"
    run "STOP_KAFKA"
  fi
}

if [ $# -lt 1 ]; then
  run "HELP"
else
  run "$1"
fi