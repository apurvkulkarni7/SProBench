#!/bin/bash
set -e

FRAMEWORK=$1
NUM_WORKERS=$2
NUM_CPU_WORKERS=$3
GENERATOR_LOAD_HZ=$4
RUN=$5
INIT_CONF_FILE=$6
SPB_SYSTEM=$7
MODE=${8:-START}

set_slurm_vars() {
  export HPC_JOB_NAME=$(echo $RUN_DIR_NAME | sed 's|\/|_|g' )
  export HPC_PROJECT_ID="$($YQ '.slurm_setup.project' $INIT_CONF_FILE)"
  export HPC_EXCLUSIVE="$($YQ '.slurm_setup.exclusive_jobs' $INIT_CONF_FILE)"
  export HPC_CHAINED_JOBS="$($YQ '.slurm_setup.chained_jobs' $INIT_CONF_FILE)"
  export HPC_MULTITHREADING="$($YQ '.slurm_setup.multithreading' $INIT_CONF_FILE)"
  export HPC_NUM_NODES="1" # Master and worker on same node
  #export HPC_NUM_NODES=$((NUM_CPU_WORKERS_i+1)) # Master and workers on different nodes

  HPC_MEM_GENERATOR="$($YQ '.generator.memory_gb' $INIT_CONF_FILE)"
  HPC_MEM_GENERATOR_TOTAL="$((HPC_MEM_GENERATOR*GENERATOR_NUM))"
  HPC_MEM_MASTER="$($YQ '.stream_processor.master.memory_gb' $INIT_CONF_FILE)"
  HPC_MEM_WORKER="$($YQ '.stream_processor.worker.memory_gb' $INIT_CONF_FILE)"
  HPC_MEM_KAFKA="$($YQ '.kafka.memory_gb' $INIT_CONF_FILE)"
  HPC_MEM_SPARE="$($YQ '.mem_node_spare' $INIT_CONF_FILE)"
  export HPC_MEM_PER_NODE="$((HPC_MEM_MASTER+HPC_MEM_WORKER+HPC_MEM_SPARE+HPC_MEM_GENERATOR_TOTAL+HPC_MEM_KAFKA))G"

  HPC_CPUS_MASTER="$($YQ '.stream_processor.master.cpu' $INIT_CONF_FILE)"
  HPC_CPUS_WORKER="$NUM_CPU_WORKERS_i"
  HPC_CPUS_KAFKA="$($YQ '.kafka.cpu' $INIT_CONF_FILE)"
  HPC_CPUS_SPARE="$($YQ '.num_cpus_spare' $INIT_CONF_FILE)"
  HPC_CPUS_GENERATOR="$($YQ '.generator.cpu' $INIT_CONF_FILE)"
  HPC_CPUS_GENERATOR_TOTAL="$((HPC_CPUS_GENERATOR*GENERATOR_NUM))"
  export HPC_CPUS_PER_NODE="$((HPC_CPUS_MASTER+HPC_CPUS_WORKER+HPC_CPUS_SPARE+HPC_CPUS_GENERATOR_TOTAL+HPC_CPUS_KAFKA))"

  BENCHMARK_RUNTIME_MIN=$((BENCHMARK_RUNTIME_MIN+10)) # Always add 5-10min extra
  export HPC_JOB_RUNTIME="$(format_time BENCHMARK_RUNTIME_MIN)"
}

#Setup experiment directory structure
setup_run_directory_structure() {
  if [[ "$FRAMEWORK" =~ (FLINK|SPARKSTRUCSTREAM|KAFKASTREAM) ]]; then
    RUN_DIR_NAME="W${NUM_WORKERS}_C${NUM_CPU_WORKERS}_L${GENERATOR_LOAD_HZ}/${PROCESSING_TYPE}/R${RUN_i}"
  elif [[ "$FRAMEWORK" =~ (MESSAGE_BROKER|MESSAGEBROKER) ]]; then
    check_var GENERATOR_LOAD_HZ
    check_var GENERATOR_NUM
    RUN_DIR_NAME="L${GENERATOR_LOAD_HZ}_G${GENERATOR_NUM}/R${RUN_i}"
  fi
  LOG_DIR_RUN="${LOG_DIR_MAIN}/${RUN_DIR_NAME}"
  mkdir -p $LOG_DIR_RUN
}

# Local machine job
system_handler_localmachine() {
  $SPB_RUN_WORKFLOW_SCRIPT_FULL
}

system_handler_slurm() {
  case $SPB_SYSTEM in
  slurm_interactive)
    if [[ -z $SLURM_JOBID ]]; then
      logger_error "No interactive job is started. Please start an interactive job"
      return 1
    fi
    $SPB_RUN_WORKFLOW_SCRIPT_FULL
    ;;
  slurm_batch)
    set_slurm_vars
    check_var HPC_PROJECT_ID
    check_var HPC_NUM_NODES
    check_var HPC_EXCLUSIVE
    check_var HPC_CHAINED_JOBS
    check_var HPC_MULTITHREADING
    check_var HPC_NUM_NODES
    check_var HPC_MEM_PER_NODE
    check_var HPC_CPUS_PER_NODE
    check_var HPC_JOB_RUNTIME

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

################################################################################

check_var GENERATOR_LOAD_HZ
if [[ "${GENERATOR_LOAD_HZ}" -ge "500000" ]]; then
  export GENERATOR_LOAD_PER_GENERATOR_HZ="500000"
  export GENERATOR_NUM="$(((GENERATOR_LOAD_HZ_i+GENERATOR_LOAD_PER_GENERATOR_HZ-1)/GENERATOR_LOAD_PER_GENERATOR_HZ))"
  export GENERATOR_LOAD_PER_GENERATOR_HZ="$((GENERATOR_LOAD_HZ/GENERATOR_NUM))"
else
  export GENERATOR_LOAD_PER_GENERATOR_HZ="${GENERATOR_LOAD_HZ_i}"
  export GENERATOR_NUM="1"
fi
BENCHMARK_RUNTIME_MIN="$($YQ '.benchmark_runtime_min' $INIT_CONF_FILE)"

setup_run_directory_structure

SPB_RUN_WORKFLOW_SCRIPT="${BENCHMARK_DIR}/utils/run_workflow.sh"
SPB_RUN_WORKFLOW_SCRIPT_FULL="${SPB_RUN_WORKFLOW_SCRIPT} ${FRAMEWORK} ${LOG_DIR_RUN} ${NUM_WORKERS} ${NUM_CPU_WORKERS} ${GENERATOR_LOAD_HZ} ${INIT_CONF_FILE} ${BENCHMARK_DIR} ${MODE}"

# Whether we are on local machine or login node?
case $SPB_SYSTEM in
'localmachine') system_handler_localmachine ;;
'slurm_interactive' | 'slurm_batch') system_handler_slurm ;;
esac
