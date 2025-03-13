#!/bin/bash
# setup_initial_parameters.sh
set -e

TEST_TYPE=$1

INIT_CONFIG_FILE="$2"
check_file INIT_CONF_FILE

# Looping parameters
export NUM_CPU_WORKERS_LIST="$(yaml $INIT_CONFIG_FILE '["parallelism_per_worker"]')"
export NUM_WORKERS_LIST="$(yaml $INIT_CONFIG_FILE '["num_workers"]')"
export GENERATOR_LOAD_HZ_LIST="$(yaml $INIT_CONFIG_FILE '["generator_load_hz"]')"
export RUNS_PER_CONFIG="$(yaml $INIT_CONFIG_FILE '["runs_per_configuration"]')"
export PROCESSING_TYPE="$(yaml $INIT_CONFIG_FILE '["processing_type"]')"

if [[ "$TEST_TYPE" == "GENERATOR" ]]; then
  #export GENERATOR_NUM="$(yaml $INIT_CONFIG_FILE '["generator_num"]')"
  export GENERATOR_CPU_NUM="$(yaml $INIT_CONFIG_FILE '["generator_cpu_num"]')"
  export MEM_GENERATOR="$(yaml $INIT_CONFIG_FILE '["generator_mem"]')"
fi
