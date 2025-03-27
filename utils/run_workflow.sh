#!/bin/bash
# run_workflow.sh [FLINK|SPARK_STRUC|SPARK_STR|KAFKASTREAM|GENERATOR] [LOG_DIR_RUN] [NUM_WORKERS] [NUM_CPU_WORKERS] [GENERATOR_LOAD_HZ] [MODE]

FRAMEWORK=$1
LOG_DIR_RUN=$2
NUM_WORKERS=$3
NUM_CPU_WORKERS=$4
GENERATOR_LOAD_HZ=$5
INIT_CONF_FILE=$6
BENCHMARK_DIR=$7
MODE=${8:-"START"}

# Initializing utilities and PyYAML
source "${BENCHMARK_DIR}/utils/utils.sh"

# Setting up directory
logger_info "Setting up experiment directory structure"

DEBUG="$($(get_curr_dir)/yaml_parser '.debug_mode' <${INIT_CONF_FILE})"

if [[ "$DEBUG" == "false" ]]; then
  case $SPB_SYSTEM in
  localmachine)
    SLURM_JOBID="localmachine"
    ;;
  slurm_interactive | slurm_batch)
    SLURM_JOBID="${SLURM_JOBID}"
    ;;
  esac
  export LOG_DIR_RUN_SAVE="$LOG_DIR_RUN"
  export TMP_DIR="$($YQ '.tmp_dir' $INIT_CONF_FILE)"
  export LOG_DIR_RUN="$(realpath ${TMP_DIR})/${SLURM_JOBID}/${LOG_DIR_RUN}"
  mkdir -p  "$LOG_DIR_RUN"
  mkdir -p "$LOG_DIR_RUN_SAVE"
fi

source "$(get_curr_dir)/setup_directory_structure.sh" "$LOG_DIR_RUN" "$FRAMEWORK" "$INIT_CONF_FILE"
# We get all the directory variables and $CONF_FILE_RUN from above line
check_file CONF_FILE_RUN

$YQ -i ".stream_processor.worker.instances = $NUM_WORKERS" $CONF_FILE_RUN
$YQ -i ".stream_processor.worker.parallelism = $NUM_CPU_WORKERS" $CONF_FILE_RUN
$YQ -i ".total_workload_hz = $GENERATOR_LOAD_HZ" $CONF_FILE_RUN

# Get yaml configuration of current run and export as the environment variable
source $BENCHMARK_DIR/utils/get_run_yaml_config.sh

# Setup Frameworks
source "${BENCHMARK_DIR}/utils/setup_framework.sh"

# Setup framework environment variables
logger_info "Setting up framework environment variables"
source "${BENCHMARK_DIR}/utils/setup_framework_env.sh"

# Setup framework configuration as per all the environment variables
logger_info "Setting up framework configuration"
source "${BENCHMARK_DIR}/utils/setup_framework_config.sh"

logger_info "==================================="
logger_info "Benchmark run started"
logger_info "==================================="
# Run the benchmark
source $BENCHMARK_DIR/utils/benchmark_main.sh "${FRAMEWORK}_TEST_$MODE"
sleep 10s

if [[ "$DEBUG" == "false" ]]; then
  cp -r "${LOG_DIR_RUN}" "$(dirname ${LOG_DIR_RUN_SAVE})/"
fi

logger_info "==================================="
logger_info "Benchmark run finished"
logger_info "==================================="
