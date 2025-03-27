#!/bin/bash
set -e

BENCHMARK_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source "${BENCHMARK_DIR}/utils/utils.sh"

source "${BENCHMARK_DIR}/utils/parse_input_args.sh" $@
logger_verbosity=$($YQ '.logging_level' $INIT_CONF_FILE)

if [[ "$SETUP" == "true" ]]; then
  exit 0
fi

check_var LOG_DIR_MAIN
check_var INIT_CONF_FILE
check_var MODE
check_var SPB_SYSTEM

# Setting up initial parameters
source "$BENCHMARK_DIR"/utils/setup_initial_parameters.sh $INIT_CONF_FILE

for FRAMEWORK_i in $FRAMEWORK_LIST; do
  for NUM_WORKERS_i in $NUM_WORKERS_LIST; do
    for NUM_CPU_WORKERS_i in $NUM_CPU_WORKERS_LIST; do
      for GENERATOR_LOAD_HZ_i in $GENERATOR_LOAD_HZ_LIST; do
        for ((RUN_i = 1; RUN_i <= "$RUNS_PER_CONFIG"; RUN_i++)); do
          # Proceed based on the system
          source ${BENCHMARK_DIR}/utils/system_handler.sh \
            $FRAMEWORK_i $NUM_WORKERS_i $NUM_CPU_WORKERS_i $GENERATOR_LOAD_HZ_i $RUN_i $INIT_CONF_FILE $SPB_SYSTEM $MODE

        done
      done
    done
  done
done
