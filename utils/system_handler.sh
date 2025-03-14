#!/bin/bash
set -e

FRAMEWORK=$1
LOG_DIR_RUN=$2
NUM_WORKERS=$3
NUM_CPU_WORKERS=$4
GENERATOR_LOAD_HZ=$5
INIT_CONF_FILE=$6
MODE=$7
SPB_SYSTEM=$8

SPB_RUN_WORKFLOW_SCRIPT="${BENCHMARK_DIR}/utils/run_workflow.sh"
SPB_RUN_WORKFLOW_SCRIPT_FULL="${SPB_RUN_WORKFLOW_SCRIPT} \
  ${FRAMEWORK} ${LOG_DIR_RUN} ${NUM_WORKERS} ${NUM_CPU_WORKERS} ${GENERATOR_LOAD_HZ} ${INIT_CONF_FILE} ${MODE}"

# Local machine job
system_handler_localmachine() {
  $($SPB_RUN_WORKFLOW_SCRIPT_FULL)
}

system_handler_slurm() {
  case $SPB_SYSTEM in
  slurm_interactive)
    if [[ -z $SLURM_JOBID ]]; then
      logger_error "No interactive job is started. Please start an interactive job"
      return 1
    fi
    run_workflow
    # "${BENCHMARK_DIR}/utils/run_workflow.sh" \
    #   $FRAMEWORK $LOG_DIR_RUN $NUM_WORKERS $NUM_CPU_WORKERS $GENERATOR_LOAD_HZ $INIT_CONF_FILE $MODE
    ;;
  slurm_batch)
    check_var HPC_PROJECT_ID
    check_var HPC_NUM_NODES
    check_var HPC_EXCLUSIVE
    check_var HPC_CHAINED_JOBS
    check_var HPC_MULTITHREADING
    check_var HPC_NUM_NODES
    check_var HPC_MEM_PER_NODE
    check_var HPC_CPUS_PER_NODE
    check_var HPC_JOB_RUNTIME

    #HPC_JOB="${BENCHMARK_DIR}/utils/run_workflow.sh $FRAMEWORK $LOG_DIR_RUN $NUM_WORKERS $NUM_CPU_WORKERS $GENERATOR_LOAD_HZ $INIT_CONF_FILE $MODE"

    #HPC_JOB_OPT="--nodes=${HPC_NUM_NODES} --mem=${HPC_MEM_PER_NODE} --cpus-per-task=${HPC_CPUS_PER_NODE} --output=${LOG_DIR_RUN}/%j.out --time=$HPC_JOB_RUNTIME --job-name=${HPC_JOB_NAME} --account=${HPC_PROJECTD}"

    # Define the sbatch job options
    SPB_SLURM_BATCH_OPTS=(
      "--nodes=${HPC_NUM_NODES}"
      "--mem=${HPC_MEM_PER_NODE}"
      "--cpus-per-task=${HPC_CPUS_PER_NODE}"
      "--output=${LOG_DIR_RUN}/%j.out"
      "--time=$HPC_JOB_RUNTIME"
      "--job-name=${HPC_JOB_NAME}"
      "--account=${HPC_PROJECT_ID}"
    )

    if [[ "${HPC_EXCLUSIVE,,}" == "true" ]]; then
      SPB_SLURM_BATCH_OPTS="${SPB_SLURM_BATCH_OPTS} --exclusive"
    fi

    if [[ "${HPC_CHAINED_JOBS,,}" == "true" ]] && [ -n "${DEPENDENCY}" ]; then
      SPB_SLURM_BATCH_OPTS="${SPB_SLURM_BATCH_OPTS} --dependency afterany:${DEPENDENCY}"
    fi

    if [[ "${HPC_MULTITHREADING,,}" == "true" ]]; then
      unset SLURM_HINT
      #SPB_SLURM_BATCH_OPTS="${SPB_SLURM_BATCH_OPTS} --hint=multithread"
      SPB_SLURM_BATCH_OPTS+=("--hint=multithread")
    fi

    SBATCH_CMD="sbatch ${SPB_SLURM_BATCH_OPTS[*]} ${SPB_RUN_WORKFLOW_SCRIPT_FULL}"

    # Final command
    TIMESTAMP=$(date +%F_%T)
    echo -n "Running command: $SBATCH_CMD"
    OUTPUT=$($SBATCH_CMD)
    echo ""
    echo "$OUTPUT"

    JOB_ID=$(echo "$OUTPUT" | awk '{print $4}')

    # Saving the command
    echo "[$TIMESTAMP]: $SBATCH_CMD" >>sbatch_cmd.log
    echo "      $OUTPUT" >>sbatch_cmd.log
    sleep 1s

    if [[ "${HPC_CHAINED_JOBS,,}" == "true" ]]; then
      DEPENDENCY=$JOB_ID
    fi

    # Postprocessing commands
    PP_DEPENDENCY=$JOB_ID
    ;;
  esac

}

# Whether we are on local machine or login node?
case $SPB_SYSTEM in
'localmachine') system_handler_localmachine ;;
'slurm_interactive' | 'slurm_batch') system_handler_slurm ;;
esac
