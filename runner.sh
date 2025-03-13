#!/bin/bash
DEPENDENCY="14975510"
is_hpc() {
  if hostname -f | grep -q 'hpc.tu-dresden'; then
    #"HPC detected"
    return 0  # Machine matches the condition
  else
    return 1  # Machine does not match the condition
  fi
}

BENCHMARK_DIR="$(dirname $(realpath $0))"

source "$BENCHMARK_DIR/utils/helper_utils.sh"

runner_input_parser "$@"

if [[ $FRAMEWORK == "CHECK" ]]; then
  $BENCHMARK_DIR/utils/check_compatibility.sh $INIT_CONF_FILE
  exit 0
fi

# Initializing utilities and PyYAML
source $BENCHMARK_DIR/utils/init.sh

check_var FRAMEWORK
check_var LOG_DIR_MAIN
check_var INIT_CONF_FILE
check_var MODE

# Setting up initial parameters
source "$BENCHMARK_DIR"/utils/setup_initial_parameters.sh $FRAMEWORK $INIT_CONF_FILE

for NUM_WORKERS_i in $NUM_WORKERS_LIST; do
  for NUM_CPU_WORKERS_i in $NUM_CPU_WORKERS_LIST; do
    for GENERATOR_LOAD_HZ_i in $GENERATOR_LOAD_HZ_LIST; do
      for (( RUN_i=1; RUN_i<="$RUNS_PER_CONFIG"; RUN_i++ )); do

        # HPC Job Parameters
        source "$BENCHMARK_DIR"/utils/setup_batch_job_parameters.sh $INIT_CONF_FILE

        #Setup experiment directory structure
        if [[ "$FRAMEWORK" == "FLINK" ]]; then
          RUN_DIR_NAME="W${NUM_WORKERS_i}_C${NUM_CPU_WORKERS_i}_L${GENERATOR_LOAD_HZ_i}/${PROCESSING_TYPE}/R${RUN_i}"
        elif [[ "$FRAMEWORK" == "GENERATOR" ]]; then
          check_var GENERATOR_NUM
          check_var GENERATOR_CPU_NUM
          check_var MEM_GENERATOR
          RUN_DIR_NAME="G${GENERATOR_NUM}_C${GENERATOR_CPU_NUM}_M${MEM_GENERATOR}_L${GENERATOR_LOAD_HZ_i}_P${NUM_CPU_WORKERS_i}/R${RUN_i}"
        fi
        LOG_DIR_RUN="${LOG_DIR_MAIN}/${RUN_DIR_NAME}"
        
        # Whether we are on local machine or login node?
        if ! is_hpc; then
          # Local machine job
          "${BENCHMARK_DIR}/utils/run_workflow.sh"  \
            $FRAMEWORK $LOG_DIR_RUN $NUM_WORKERS_i $NUM_CPU_WORKERS_i $GENERATOR_LOAD_HZ_i $INIT_CONF_FILE $MODE
        else
          if [[ ! -z $SLURM_JOBID ]]; then 
            # Interactive job
            "${BENCHMARK_DIR}/utils/run_workflow.sh" \
              $FRAMEWORK $LOG_DIR_RUN $NUM_WORKERS_i $NUM_CPU_WORKERS_i $GENERATOR_LOAD_HZ_i $INIT_CONF_FILE $MODE
          else
            check_var HPC_PROJECT_ID
            check_var HPC_NUM_NODES
            check_var HPC_EXCLUSIVE
            check_var HPC_CHAINED_JOBS
            check_var HPC_MULTITHREADING
            check_var HPC_NUM_NODES
            check_var HPC_MEM_PER_NODE
            check_var HPC_CPUS_PER_NODE
            check_var HPC_JOB_RUNTIME

            HPC_JOB="${BENCHMARK_DIR}/utils/run_workflow.sh $FRAMEWORK $LOG_DIR_RUN $NUM_WORKERS_i $NUM_CPU_WORKERS_i $GENERATOR_LOAD_HZ_i $INIT_CONF_FILE $MODE"

            HPC_JOB_OPT="--nodes=${HPC_NUM_NODES} --mem=${HPC_MEM_PER_NODE} --cpus-per-task=${HPC_CPUS_PER_NODE} --output=${LOG_DIR_RUN}/%j.out --time=$HPC_JOB_RUNTIME --job-name=${HPC_JOB_NAME} --account=${HPC_PROJECT_ID}"

            if [[ "${HPC_EXCLUSIVE,,}" == "true" ]]; then
              HPC_JOB_OPT="${HPC_JOB_OPT} --exclusive"
            fi

            if [[ "${HPC_CHAINED_JOBS,,}" == "true" ]] && [ -n "${DEPENDENCY}" ] ; then
                HPC_JOB_OPT="${HPC_JOB_OPT} --dependency afterany:${DEPENDENCY}"
            fi

            if [[ "${HPC_MULTITHREADING,,}" == "true" ]]; then
              unset SLURM_HINT
              HPC_JOB_OPT="${HPC_JOB_OPT} --hint=multithread"
            fi

            SBATCH_CMD="sbatch ${HPC_JOB_OPT} ${HPC_JOB}"

            # Final command
            timestamp=$(date +%Y%m%d_%H%M%S)
            echo -n "Running command: $SBATCH_CMD"
            OUT=`$SBATCH_CMD`
            echo ""
            echo "$OUT"
            if [[ "${HPC_CHAINED_JOBS,,}" == "true" ]]; then
              DEPENDENCY=`echo $OUT | awk '{print $4}'`
            fi

            # Saving the command
            echo "[$timestamp]: $SBATCH_CMD"  >> sbatch_cmd.log
            echo "      $OUT" >> sbatch_cmd.log
            sleep 1s

            # Postprocessing commands
            PP_DEPENDENCY=`echo $OUT | awk '{print $4}'`
            
          fi
        fi
      done
    done
  done
done
