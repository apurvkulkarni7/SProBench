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

          # HPC Job Parameters
          source "$BENCHMARK_DIR"/utils/setup_batch_job_parameters.sh $INIT_CONF_FILE

          #Setup experiment directory structure
          if [[ "$FRAMEWORK_i" =~ (FLINK|SPARK_STREAMING|KAFKASTREAM) ]]; then
            RUN_DIR_NAME="W${NUM_WORKERS_i}_C${NUM_CPU_WORKERS_i}_L${GENERATOR_LOAD_HZ_i}/${PROCESSING_TYPE}/R${RUN_i}"
          elif [[ "$FRAMEWORK_i" =~ (MESSAGE_BROKER) ]]; then
            check_var GENERATOR_NUM
            check_var GENERATOR_CPU_NUM
            check_var MEM_GENERATOR
            RUN_DIR_NAME="G${GENERATOR_NUM}_C${GENERATOR_CPU_NUM}_M${MEM_GENERATOR}_L${GENERATOR_LOAD_HZ_i}_P${NUM_CPU_WORKERS_i}/R${RUN_i}"
          fi
          LOG_DIR_RUN="${LOG_DIR_MAIN}/${RUN_DIR_NAME}"
          mkdir -p $LOG_DIR_RUN

          # Proceed based on the system
          source ${BENCHMARK_DIR}/utils/system_handler.sh \
            $FRAMEWORK_i $LOG_DIR_RUN $NUM_WORKERS_i $NUM_CPU_WORKERS_i $GENERATOR_LOAD_HZ_i $INIT_CONF_FILE $MODE $SPB_SYSTEM

        done
      done
    done
  done
done
