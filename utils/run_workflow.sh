#!/bin/bash
# run_workflow.sh [FLINK|SPARK_STRUC|SPARK_STR|KAFKASTREAM|GENERATOR] [LOG_DIR_RUN] [NUM_WORKERS] [NUM_CPU_WORKERS] [GENERATOR_LOAD_HZ] [MODE]

FRAMEWORK=$1
LOG_DIR_RUN=$2
NUM_WORKERS=$3
NUM_CPU_WORKERS=$4
GENERATOR_LOAD_HZ=$5
INIT_CONF_FILE=$6
MODE=${7:-"START"}

export BENCHMARK_DIR="$(realpath ./)"

# Initializing utilities and PyYAML
source "$BENCHMARK_DIR"/utils/init.sh

# Setting up directory
logger_info "Setting up experiment directory structure"

export LOG_DIR_RUN_SAVE="$LOG_DIR_RUN"
export LOG_DIR_RUN="/dev/shm/${SLURM_JOBID}/$LOG_DIR_RUN"
mkdir -p "$LOG_DIR_RUN_SAVE"

source "$BENCHMARK_DIR"/utils/setup_directory_structure.sh "$LOG_DIR_RUN" "$FRAMEWORK" "$INIT_CONF_FILE"
# We get all the directory variables and $CONF_FILE_RUN from above line

check_file CONF_FILE_RUN

yaml_append '["num_workers"]' "$NUM_WORKERS" "$CONF_FILE_RUN"
yaml_append '["parallelism_per_worker"]' "$NUM_CPU_WORKERS" "$CONF_FILE_RUN"
yaml_append '["generator_load_hz"]' "$GENERATOR_LOAD_HZ" "$CONF_FILE_RUN"

# Get yaml configuration of current run and export as the environment variable
source $BENCHMARK_DIR/utils/get_run_yaml_config.sh $FRAMEWORK

# Setup Frameworks
source $BENCHMARK_DIR/utils/setup_framework.sh $FRAMEWORK "$CONF_FILE_RUN"

# Setup framework environment variables
logger_info "Setting up framework environment variables"
source $BENCHMARK_DIR/utils/setup_framework_env.sh $FRAMEWORK

# Setup framework configuration as per all the environment variables
logger_info "Setting up framework configuration"
source $BENCHMARK_DIR/utils/setup_framework_config.sh $FRAMEWORK

logger_info "==================================="
logger_info "Benchmark run started"
logger_info "==================================="
# Run the benchmark
source $BENCHMARK_DIR/utils/benchmark_main.sh "${FRAMEWORK}_TEST_$MODE"
sleep 10s

cp -r "${LOG_DIR_RUN}" "$(dirname ${LOG_DIR_RUN_SAVE})/"

logger_info "==================================="
logger_info "Benchmark run finished"
logger_info "==================================="
