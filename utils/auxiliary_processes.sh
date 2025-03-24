#!/bin/bash
set -e

# JMX processes
run_jmx_collector() {
  local host=$1
  local metric_collector=$2
  local process_name=$3 # Process which needs to be tracked
  
  local jobid=$SLURM_JOBID
  local process_mem="300M"
  local jmx_classpath="${BENCHMARK_DIR}/benchmark-utils/target/benchmark-utils-1.0.jar org.metrics.${metric_collector}"
  local jmx_jvm_opt="-DlogDir=${LOG_DIR_RUN_LOG_JMX}"
  local METRIC_LOGGING_INTERVAL_MS=$((METRIC_LOGGING_INTERVAL_SEC * 1000))

  if [[ "${metric_collector}" == "JVMMetricExtractor" ]]; then
    local file_prefix=$4
    local jmx_pid_file="${LOG_DIR_RUN_LOG_JMX}/${file_prefix}_JVMMetricExtractorApp.log.pid"

    # Define application options
    jmx_jvm_opt="$jmx_jvm_opt -DmainLogFileName=${file_prefix}_JVMMetricExtractorApp.log"
    jmx_jvm_opt="$jmx_jvm_opt -DmetricLogFileName=${file_prefix}_jvm.csv"

    local jmx_app_opt="-rt pid -iqf ${BENCHMARK_DIR}/utils/inputMetricList.log -li ${METRIC_LOGGING_INTERVAL_MS} -jpn ${process_name}"

  elif [[ "${metric_collector}" == "KafkaMetricExtractor" ]]; then
    local kafka_topics=$4
    # local regex_patt=$5
    local jmx_pid_file="${LOG_DIR_RUN_LOG_JMX}/${kafka_topics}_KafkaMetricsExtractorApp.log.pid"
    jmx_jvm_opt="$jmx_jvm_opt -DmainLogFileName=${kafka_topics}_KafkaMetricsExtractorApp.log -DmetricLogFileName=${kafka_topics}_throughput_latency.csv"
    # jmx_app_opt="-rt pid -jpn ${process_name} -ktl ${kafka_topics} -rgx '${regex_patt}' -kbs ${KAFKA_SOURCE_BOOTSTRAP_SERVER} -li ${METRIC_LOGGING_INTERVAL_MS} --all"
    jmx_app_opt="-rt pid -jpn ${process_name} -ktl ${kafka_topics} -kbs ${KAFKA_SOURCE_BOOTSTRAP_SERVER} -li ${METRIC_LOGGING_INTERVAL_MS} --all"
  else
    logger_error "Incorrect input for \"metric_collector\": $metric_collector."
    exit 1
  fi
  sleep 5s

  local jmx_cmd="${JAVA} ${jmx_jvm_opt} -cp ${jmx_classpath} ${jmx_app_opt}"

  # Start the application
  if is_hpc; then
    srun --overlap -N1 -c1 --mem=${process_mem} --nodelist=$host --jobid=$jobid --time=$(get_slurm_jobtime) \
      /bin/bash -c "$jmx_cmd 2>&1 >> ${LOG_DIR_RUN_LOG_JMX}/apps.log" &
  else
    exec $jmx_cmd &
  fi
  sleep 5s

  # Check if the application is running or not
  local jmx_check_cmd="jps | grep -q \$(cat $jmx_pid_file)"
  #local jmx_check_cmd="pgrep -U ${USER} -F ${jmx_pid_file} > /dev/null 2>&1"

  if run_remote_cmd "${host}" "${jmx_check_cmd}" > /dev/null ; then
    logger_info "Started ${metric_collector} on: ${host}"
  else
    logger_info "${metric_collector} not running. Check pipeline."
    logger_info "Stopping the program."
    trap_ctrlc
    exit 1
  fi
}

monitor_kafka_broker() {
    # monitor_kafka_broker NODE_ID SLURM_JOBID  RUNTIME_SEC CHECK_INTERVAL STATUS_FILE
    local kafka_broker=$1
    local slurm_jobid=$2
    local runtime=$3 # in seconds
    local check_interval="${4:-"10"}s"
    local status_file=${5:-"$HOME/${slurm_jobid}_STATUS"}

    local start_time=$(date +%s)
    local current_time
    echo "Starting Kafka monitor"
    echo "SUCCESS" > $status_file
    while true; do

        current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))
        
        if [[ "$elapsed_time" -ge "$runtime" ]]; then
            #echo "Monitoring duration exceeded. Exiting monitoring script."
            exit 0
        fi

        # Check if Kafka broker is alive using SSH
        if ! srun --overlap --nodelist="$kafka_broker" --jobid="$slurm_jobid" /bin/bash -c "jps" | grep -q -E "Kafka|QuorumPeerMain"; then
            echo "Kafka broker is dead or unreachable. Terminating Slurm job $slurm_jobid."
            echo "FAILED" > $status_file
            #cp $LOG_DIR_RUN $LOG_DIR_RUN_SAVE
            scancel $slurm_jobid
            exit 1
        fi
        # Sleep for the specified interval before next check
        sleep $check_interval
    done
}
