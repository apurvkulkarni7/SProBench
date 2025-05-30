#!/bin/bash
set -e

check_file CONF_FILE_RUN

$YQ -i ".stream_processor.worker.instances = $NUM_WORKERS" $CONF_FILE_RUN
$YQ -i ".stream_processor.worker.parallelism = $NUM_CPU_WORKERS" $CONF_FILE_RUN
$YQ -i ".total_workload_hz = $GENERATOR_LOAD_HZ" $CONF_FILE_RUN

export GENERATOR_TYPE="$($YQ '.generator.type' $CONF_FILE_RUN)"
export GENERATOR_LOAD_HZ="$($YQ '.total_workload_hz' $CONF_FILE_RUN)"
export GENERATOR_LOAD_PER_GENERATOR_HZ="$((GENERATOR_LOAD_HZ/GENERATOR_NUM))"
export GENERATOR_NUM="$(((GENERATOR_LOAD_HZ+GENERATOR_LOAD_PER_GENERATOR_HZ-1)/GENERATOR_LOAD_PER_GENERATOR_HZ))"

export GENERATOR_CPU_NUM="$($YQ '.generator.cpu' $CONF_FILE_RUN)"
export GENERATOR_THREAD_PER_CPU_NUM="$($YQ '.generator.threads_per_cpu_num' $CONF_FILE_RUN)"
export GENERATOR_CPU_NUM_TOTAL=$((GENERATOR_CPU_NUM*GENERATOR_NUM))
export ONLY_DATA_GENERATOR="$($YQ '.generator.only_data_generator' $CONF_FILE_RUN)"
export GENERATOR_RECORD_SIZE_B="$($YQ '.generator.record_size_bytes' $CONF_FILE_RUN)"

export BENCHMARK_RUNTIME_MIN="$($YQ '.benchmark_runtime_min' $CONF_FILE_RUN)"
export METRIC_LOGGING_INTERVAL_SEC="$($YQ '.metric_logging_interval_sec' $CONF_FILE_RUN)"
export PROCESSING_TYPE="$($YQ '.stream_processor.processing_type' $CONF_FILE_RUN)"

export KAFKA_SOURCE_TOPICS="$($YQ '.kafka.source_topics[].name' $CONF_FILE_RUN)" # Assuming only single source topic
export KAFKA_SINK_TOPICS="$($YQ '.kafka.sink_topics[].name' $CONF_FILE_RUN)" # Assuming only single sink topic

export NUM_WORKERS="$($YQ '.stream_processor.worker.instances' $CONF_FILE_RUN)"

export NUM_CPU_MASTER="$($YQ '.stream_processor.master.cpu' $CONF_FILE_RUN)"
export NUM_CPU_WORKERS="$($YQ '.stream_processor.worker.parallelism' $CONF_FILE_RUN)"
export NUM_CPU_WORKERS_SPARE="$($YQ '.num_cpus_spare' $CONF_FILE_RUN)"

MEM_MASTER="$($YQ '.stream_processor.master.memory_gb' $CONF_FILE_RUN)"
MEM_NODE_WORKER="$($YQ '.stream_processor.worker.memory_gb' $CONF_FILE_RUN)"
MEM_NODE_WORKER_SPARE="$($YQ '.mem_node_spare' $CONF_FILE_RUN)"
MEM_GENERATOR="$($YQ '.generator.memory_gb' $CONF_FILE_RUN)"
MEM_GENERATOR_TOTAL=$((MEM_GENERATOR*GENERATOR_NUM))

if [[ "${SBP_SYSTEM}" =~ "slurm*" ]]; then

  # Get some extra system information after job is initialized
  scontrol show --json jobid $SLURM_JOBID > $LOG_DIR_RUN_CONFIG/slurm_job_info.json
  cp /proc/cpuinfo "${LOG_DIR_RUN_CONFIG}"/slurm_cpu_info.out
  module load GCC/13.2.0
  module load OpenMPI/4.1.6
  lstopo --no-factorize --no-collapse --force $LOG_DIR_RUN_CONFIG/topology.svg
  module unload OpenMPI/4.1.6

  REQ_CPU_NUM=$((NUM_CPU_MASTER+NUM_CPU_WORKERS+NUM_CPU_WORKERS_SPARE+GENERATOR_CPU_NUM_TOTAL)) #This logic is good only if all the processes on same node
  MAX_CPU_NUM=$((SLURM_CPUS_PER_TASK*SLURM_JOB_NUM_NODES))
  if [[ "$REQ_CPU_NUM" -gt "$MAX_CPU_NUM" ]]; then
    logger_error "More CPUs are requested than the SLURM job."
    logger_error "Please either reduce the CPU allocation to the benchmark proceses or increase SLURM job resources"
    exit 1
  fi
  REQ_MEM_NODE=$((MEM_MASTER+MEM_NODE_WORKER+MEM_NODE_WORKER_SPARE+MEM_GENERATOR_TOTAL))
  MAX_MEM_NODE=$(get_mem_per_node)
  MAX_MEM_NODE_UNIT=${MAX_MEM_NODE:(-1)}
  MAX_MEM_NODE=${MAX_MEM_NODE%[GgMm]}
  check_var MAX_MEM_NODE
  if [[ "$MAX_MEM_NODE_UNIT" != "G" ]]; then
    logger_error "SLURM job memory unit doesn't match with 'G'. Aborting."
    exit 0
  fi
  if [[ "$REQ_MEM_NODE" -gt "$MAX_MEM_NODE" ]]; then
    logger_error "More MEM is requested than the SLURM job."
    logger_error "Please either reduce the requested memory or increase SLURM job resources"
    exit 1
  fi
fi
# Assigning Gigabit (G) memory units to the values.
export MEM_MASTER="${MEM_MASTER}G"
export MEM_NODE_WORKER="${MEM_NODE_WORKER}G"
export MEM_NODE_WORKER_SPARE="${MEM_NODE_WORKER_SPARE}G"
export MEM_GENERATOR="${MEM_GENERATOR}G"