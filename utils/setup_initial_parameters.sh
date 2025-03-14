#!/bin/bash
# setup_initial_parameters.sh
set -e

  INIT_CONF_FILE="$1"

check_file INIT_CONF_FILE

# Looping parameters
export NUM_CPU_WORKERS_LIST="$(yaml $INIT_CONF_FILE '["parallelism_per_worker"]')"
export NUM_WORKERS_LIST="$(yaml $INIT_CONF_FILE '["num_workers"]')"
export GENERATOR_LOAD_HZ_LIST="$(yaml $INIT_CONF_FILE '["generator_load_hz"]')"
export RUNS_PER_CONFIG="$(yaml $INIT_CONF_FILE '["runs_per_configuration"]')"
export PROCESSING_TYPE="$(yaml $INIT_CONF_FILE '["processing_type"]')"
export FRAMEWORK_LIST="$(yaml $INIT_CONF_FILE '["processing_framework"]')"

FRAMEWORK_LIST=${FRAMEWORK_LIST^^}

if [[ "$TEST_TYPE" == "GENERATOR" ]]; then
  #export GENERATOR_NUM="$(yaml $INIT_CONF_FILE '["generator_num"]')"
  export GENERATOR_CPU_NUM="$(yaml $INIT_CONF_FILE '["generator_cpu_num"]')"
  export MEM_GENERATOR="$(yaml $INIT_CONF_FILE '["generator_mem"]')"
fi
