#!/bin/bash
set -e

INIT_CONF_FILE=$1

check_file INIT_CONF_FILE
 
export HPC_JOB_NAME="$RUN_DIR_NAME"
export HPC_PROJECT_ID="$(yaml $INIT_CONF_FILE '["hpc_setup"]["project"]')"
export HPC_EXCLUSIVE="$(yaml $INIT_CONF_FILE '["hpc_setup"]["exclusive_jobs"]')"
export HPC_CHAINED_JOBS="$(yaml $INIT_CONF_FILE '["hpc_setup"]["chained_jobs"]')"
export HPC_MULTITHREADING="$(yaml $INIT_CONF_FILE '["hpc_setup"]["multithreading"]')"
export HPC_NUM_NODES="1" # Master and worker on same node
#export HPC_NUM_NODES=$((NUM_CPU_WORKERS_i+1)) # Master and workers on different nodes

check_var GENERATOR_LOAD_HZ_i
if [[ "${GENERATOR_LOAD_HZ_i}" -ge "500000" ]]; then
  export GENERATOR_LOAD_PER_GENERATOR_HZ="500000"
  export GENERATOR_NUM="$(((GENERATOR_LOAD_HZ_i+GENERATOR_LOAD_PER_GENERATOR_HZ-1)/GENERATOR_LOAD_PER_GENERATOR_HZ))"
  # Adjusting the load per generator based on calculated number of generator
  export GENERATOR_LOAD_PER_GENERATOR_HZ="$((GENERATOR_LOAD_HZ/GENERATOR_NUM))"
else
  export GENERATOR_LOAD_PER_GENERATOR_HZ="${GENERATOR_LOAD_HZ_i}"
  export GENERATOR_NUM="1"
fi

HPC_MEM_GENERATOR="$(yaml $INIT_CONF_FILE '["generator_mem"]')"
HPC_MEM_GENERATOR_TOTAL="$((HPC_MEM_GENERATOR*GENERATOR_NUM))"
HPC_MEM_MASTER="$(yaml $INIT_CONF_FILE '["mem_node_master"]')"
HPC_MEM_WORKER="$(yaml $INIT_CONF_FILE '["mem_node_worker"]')"
HPC_MEM_SPARE="$(yaml $INIT_CONF_FILE '["mem_node_spare"]')"
export HPC_MEM_PER_NODE="$(( HPC_MEM_MASTER + HPC_MEM_WORKER + HPC_MEM_SPARE + HPC_MEM_GENERATOR_TOTAL ))G"

HPC_CPUS_MASTER="$(yaml $INIT_CONF_FILE '["num_cpus_master"]')"
HPC_CPUS_WORKER="$NUM_CPU_WORKERS_i" #"$(yaml $INIT_CONF_FILE '["parallelism_per_worker"]')"
HPC_CPUS_SPARE="$(yaml $INIT_CONF_FILE '["num_cpus_spare"]')"
HPC_CPUS_GENERATOR="$(yaml $INIT_CONF_FILE '["generator_cpu_num"]')"
HPC_CPUS_GENERATOR_TOTAL="$((HPC_CPUS_GENERATOR*GENERATOR_NUM))"

export HPC_CPUS_PER_NODE="$((HPC_CPUS_MASTER+HPC_CPUS_WORKER+HPC_CPUS_SPARE+HPC_CPUS_GENERATOR_TOTAL))"

BENCHMARK_RUNTIME_MIN="$(yaml $INIT_CONF_FILE '["benchmark_runtime_min"]')"
BENCHMARK_RUNTIME_MIN=$((BENCHMARK_RUNTIME_MIN+10)) # Always add 5-10min extra
export HPC_JOB_RUNTIME="$(format_time BENCHMARK_RUNTIME_MIN)"
