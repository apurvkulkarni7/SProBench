#!/bin/bash
# setup_initial_parameters.sh
set -e

CURR_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

INIT_CONF_FILE="$1"
check_file INIT_CONF_FILE

# Looping parameters
NUM_CPU_WORKERS_LIST="$($YQ  '.stream_processor.worker.parallelism | join(" ")' $INIT_CONF_FILE)"
NUM_WORKERS_LIST="$($YQ '.stream_processor.worker.instances | join(" ")' $INIT_CONF_FILE)"
GENERATOR_LOAD_HZ_LIST="$($YQ '.total_workload_hz | join(" ")' $INIT_CONF_FILE)"
RUNS_PER_CONFIG="$($YQ '.runs_per_configuration' $INIT_CONF_FILE)"
PROCESSING_TYPE="$($YQ '.stream_processor.processing_type' $INIT_CONF_FILE)"
FRAMEWORK_LIST="$($YQ '.stream_processor.framework | join(" ")' $INIT_CONF_FILE)"

FRAMEWORK_LIST=${FRAMEWORK_LIST^^}

if [[ "$FRAMEWORK_LIST" =~ "(GENERATOR|MESSAGE_BROKER)" ]]; then
  GENERATOR_CPU_NUM="$($YQ '.generator.cpu' $INIT_CONF_FILE)"
  MEM_GENERATOR="$($YQ '.generator.memory_gb' $INIT_CONF_FILE)"
fi
