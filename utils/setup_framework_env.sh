#!/bin/bash
set -e

check_var SPB_SYSTEM
check_var FRAMEWORK

# Copy configuration from template directory
case $SPB_SYSTEM in
localmachine)
  cp -r $FRAMEWORK_CONFIG_TEMPLATE_KAFKA $LOG_DIR_RUN_CONFIG/
  if [[ "$FRAMEWORK" == "FLINK" ]]; then
    cp -r $FRAMEWORK_CONFIG_TEMPLATE_FLINK $LOG_DIR_RUN_CONFIG/
  fi

  NODE_LIST="localhost"
  ;;
slurm_interactive|slurm_batch)
  source framework-configure.sh --framework kafka --template $FRAMEWORK_CONFIG_TEMPLATE_KAFKA --destination $LOG_DIR_RUN_CONFIG
  # Initialize framework configuration
  FRAMEWORK_CONFIG_TEMPLATE="FRAMEWORK_CONFIG_TEMPLATE_${FRAMEWORK^^}" # Construct the variable name
  source framework-configure.sh --framework ${FRAMEWORK,,} --template ${!FRAMEWORK_CONFIG_TEMPLATE} --destination $LOG_DIR_RUN_CONFIG

  NODE_LIST=$(scontrol show hostname $SLURM_NODELIST | sort -u)
  ;;
esac
export NODE_LIST=($NODE_LIST)

#export ARCHITECTURE_TYPE=0
logger_info "Total available nodes: ${NODE_LIST[*]}"

#################################################################
# Framework env configuration
#################################################################
case ${FRAMEWORK,,} in
flink)
  export FLINK_MASTER="${NODE_LIST[0]}"
  case $SPB_SYSTEM in
  localmachine)
    export FLINK_WORKERS="$FLINK_MASTER"
    export FLINK_WORKERS_NUM="$NUM_WORKERS"
    export FLINK_SLOTS_PER_TASKMANAGER="$NUM_CPU_WORKERS"
    export FLINK_PARALLELISM=${FLINK_PARALLELISM:-$((FLINK_SLOTS_PER_TASKMANAGER * FLINK_WORKERS_NUM))}
    export FLINK_MEM_MASTER=${MEM_MASTER:-"3G"}
    export FLINK_MEM_PER_WORKER=${MEM_NODE_WORKER:-"3G"}
    export FLINK_MEM_PER_WORKER_SPARE=$MEM_NODE_WORKER_SPARE
    ;;
  slurm_interactive | slurm_batch)
    export FLINK_WORKERS_NUM=$NUM_WORKERS
    if [[ "${#NODE_LIST[@]}" -eq 1 ]]; then
      #if [[ "${FLINK_WORKERS_NUM}" -eq 1 ]]; then
      # current setup
      #            -------------------------------------------------------
      # Node1      | Generator, Kafka broker, Flink Master, Flink worker |
      #            -------------------------------------------------------
      export FLINK_WORKERS=$FLINK_MASTER
    else
      # this setup
      #            ------------------------------------------
      # Node1      |  Generator, Kafka broker, Flink Master |
      #            ------------------------------------------
      #            -----------------  -----------------
      # Node 2..x  | Flink Worker1 |  | Flink Worker2 |  ...
      #            -----------------  -----------------
      #
      export FLINK_WORKERS_TMP=${NODE_LIST[@]:1} # Removing 1st node
      export FLINK_WORKERS=${FLINK_WORKERS_TMP}

      # Another configuration could be
      #            ----------------------------
      # Node1      |  Kafka broker, Generator |
      #            ----------------------------
      #            ----------------
      # Node2      | Flink Master |
      #            ----------------
      #            -----------------  -----------------
      # Node 3..x  | Flink Worker1 |  | Flink Worker2 |  ...
      #            -----------------  -----------------
    fi
    export FLINK_SLOTS_PER_TASKMANAGER=$NUM_CPU_WORKERS
    #      tmp_sptm=$FLINK_SLOTS_PER_TASKMANAGER
    #      ((tmp_sptm=tmp_sptm-SPARE_CORES_PER_NODE))
    #      if [[ "${tmp_sptm}" -lt "1" ]]; then
    #          echo "No CPUs available for taskmanager. Allocate higher CPUs or reduces spare CPUs"
    #          echo "Available CPUs/node: ${SLURM_CPUS_ON_NODE}"
    #          echo "CPUs/node allocated for Taskmanager: ${tmp_sptm}"
    #          exit 1
    #      fi
    #export FLINK_SLOTS_PER_TASKMANAGER=${FLINK_SLOTS_PER_TASKMANAGER:-$tmp_sptm}
    #export FLINK_PARALLELISM=${FLINK_PARALLELISM:-$((${#FLINK_WORKERS_NUM[@]}*$FLINK_SLOTS_PER_TASKMANAGER))}
    export FLINK_PARALLELISM=${FLINK_PARALLELISM:-$((FLINK_SLOTS_PER_TASKMANAGER * FLINK_WORKERS_NUM))}

    export FLINK_MEM_MASTER="${MEM_MASTER}"
    export FLINK_MEM_PER_WORKER="${MEM_NODE_WORKER}"
    export FLINK_MEM_PER_WORKER_SPARE="${MEM_NODE_WORKER_SPARE}"

    # Memory
    if [[ -z ${MEM_NODE_WORKER} ]]; then
      echo "Computing TM memory."
      total_memory=$(scontrol show jobid $SLURM_JOBID | tr '\n' '\r' | sed 's/\S*.*mem=\([0-9]*\)\w.*\S*/\1\n/g')
      ((taskmanager_memory = total_memory / $SLURM_JOB_NUM_NODES))

      # Total node memory to be allocated for taskmanager
      # TODO Currently implemented for 1TM/node. Extend this for multiple TM/node
      spare_mem_per_node_val=$(echo $SPARE_MEMORY_PER_NODE | grep -oP '\d*')
      spare_mem_per_node_unit=$(echo $SPARE_MEMORY_PER_NODE | grep -oP '[^\d]*')
      ((taskmanager_memory = taskmanager_memory - $spare_mem_per_node_val))
      export FLINK_MEM_NODE_WORKER="${taskmanager_memory}G" # This is used only when a single taskmanager/node is used
    fi
    ;;
  esac

  # Variables independent of setup type
  #export FLINK_CHECKPOINT_INTERVAL="${FLINK_CHECKPOINT_INTERVAL:-"60000"}" #in ms
  #export USE_SINK=${USE_SINK:-"0"}

  check_directory LOG_DIR_RUN_LOG_FLINK
  check_directory LOG_DIR_RUN_CONFIG_FLINK

  export FLINK_LOG_DIR="$LOG_DIR_RUN_LOG_FLINK"
  export FLINK_CONF_DIR="$LOG_DIR_RUN_CONFIG_FLINK"

  export FLINK_MASTER_FILE="$FLINK_CONF_DIR/masters"
  export FLINK_WORKERS_FILE="$FLINK_CONF_DIR/workers"
  export FLINK_CONF_YAML_FILE="$FLINK_CONF_DIR/flink-conf.yaml"
  ;;
spark)
  logger_error "Not implemented yet."
  exit 1
  ;;
esac

#################################################################
# Kafka configuration
#################################################################
export KAFKA_SOURCE_TOPICS=${KAFKA_SOURCE_TOPICS:-"events"}
export KAFKA_SOURCE_PARTITION_NUM="${NUM_CPU_WORKERS}"
export KAFKA_SINK_TOPICS=${KAFKA_SINK_TOPICS:-"events-sink"}
export KAFKA_SINK_PARTITION_NUM="${NUM_CPU_WORKERS}"

check_directory LOG_DIR_RUN_LOG_KAFKA
export LOG_DIR="$LOG_DIR_RUN_LOG_KAFKA"
export KAFKA_LOG4J_OPTS_GEN="-Dlog4j.configuration=file:$LOG_DIR_RUN_CONFIG_KAFKA/log4j.properties"
export KAFKA_LOG4J_OPTS="$KAFKA_LOG4J_OPTS_GEN"
export KAFKA_LOG4J_OPTS_TOPIC="-Dlog4j.configuration=file:$LOG_DIR_RUN_CONFIG_KAFKA/tools-log4j.properties"

check_directory LOG_DIR_RUN_CONFIG_KAFKA
export KAFKA_CONFIG_SERVER_FILE="$LOG_DIR_RUN_CONFIG_KAFKA/kraft/server.properties"
export KAFKA_CONFIG_PRODUCER_PROP_FILE="$LOG_DIR_RUN_CONFIG_KAFKA/producer.properties"
# export KAFKA_LOG_DIR="/tmp/${USER}/${SLURM_JOBID}/${LOG_DIR_RUN_LOG_KAFKA}/kafka-logs" # this is different from actual logging directory
# export KAFKA_LOG_DIR="$LOG_DIR_RUN_LOG_KAFKA/tmp/$USER/kafka-logs" # this is different from actual logging directory
export KAFKA_LOG_DIR="/dev/shm/${USER}/${SLURM_JOBID}/$LOG_DIR_RUN_LOG_KAFKA/kafka-logs" # this is different from actual logging directory

if ! is_hpc; then
  # Kafka configuration
  #  export KAFKA_SOURCE_HOST="$(hostname)"
  export KAFKA_SOURCE_HOST="localhost"
  export KAFKA_SOURCE_PORT="9092"
  export KAFKA_SOURCE_BOOTSTRAP_SERVER="${KAFKA_SOURCE_HOST}:${KAFKA_SOURCE_PORT}"
  #  export KAFKA_SOURCE_TOPICS=${KAFKA_SOURCE_TOPICS:-"events"}
  #  export KAFKA_SOURCE_PARTITION_NUM="${NUM_CPU_WORKERS}"

  #  export KAFKA_SINK_HOST="$(hostname)"
  export KAFKA_SINK_HOST="localhost"
  export KAFKA_SINK_PORT="9092"
  export KAFKA_SINK_BOOTSTRAP_SERVER="${KAFKA_SINK_HOST}:${KAFKA_SINK_PORT}"
  #  export KAFKA_SINK_TOPICS=${KAFKA_SINK_TOPICS:-"events-sink"}
  #  #export KAFKA_SINK_PARTITION_NUM="${KAFKA_SINK_PARTITION_NUM:-"1"}"
  #  export KAFKA_SINK_PARTITION_NUM="${NUM_CPU_WORKERS}"

  export KAFKA_CONF_DIR="$LOG_DIR_RUN_CONFIG_KAFKA"

else

  # Kafka configuration
  # Processing Kafka Source
  export KAFKA_SOURCE_HOST="${NODE_LIST[0]}" # Currently using only one broker on one host
  export KAFKA_SOURCE_PORT="9092"
  export KAFKA_SOURCE_BOOTSTRAP_SERVER="${KAFKA_SOURCE_HOST}:${KAFKA_SOURCE_PORT}"

  # Processing Kafka Sink
  export KAFKA_SINK_HOST="${NODE_LIST[0]}"
  export KAFKA_SINK_PORT="9092"
  export KAFKA_SINK_BOOTSTRAP_SERVER="${KAFKA_SINK_HOST}:${KAFKA_SINK_PORT}"

  # Kafka architecture
  #   1: single node setup. Kafka on master node
  #   2: Single/multi node setup. Kafka on worker node (different node than master node)

  export KAFKA_ARCH="1"
  if [[ "${KAFKA_ARCH}" == "1" ]]; then
    #   NODE_ID=1
    #   sed -i 's|KAFKA_SERVER_HOSTNAME|'$KAFKA_SOURCE_HOST'|g' "$KAFKA_CONFIG_SERVER_FILE"
    #   sed -i 's|NODE_ID|'$NODE_ID'|g' "$KAFKA_CONFIG_SERVER_FILE"
    #   sed -i 's|KAFKA_SERVER_HOSTNAME_ALL|'$NODE_ID'@'$KAFKA_SOURCE_HOST':9093|g' "$KAFKA_CONFIG_SERVER_FILE"

    export KAFKA_SOURCE_HOST="${NODE_LIST[0]}" # Currently using only one broker on one host
    export KAFKA_SOURCE_PORT="9092"
    export KAFKA_SOURCE_BOOTSTRAP_SERVER="${KAFKA_SOURCE_HOST}:${KAFKA_SOURCE_PORT}"

    # Processing Kafka Sink
    export KAFKA_SINK_HOST="${KAFKA_SOURCE_HOST}"
    export KAFKA_SINK_PORT="${KAFKA_SOURCE_PORT}"
    export KAFKA_SINK_BOOTSTRAP_SERVER="${KAFKA_SOURCE_BOOTSTRAP_SERVER}"

  elif [[ "${KAFKA_ARCH}" == "2" ]]; then
    if [[ "$MODE" == "GENERATOR" ]]; then
      WORKERS="${NODE_LIST[0]}"
    else
      WORKERS="$FLINK_WORKERS"
    fi
    NODE_ID=1
    # TMP_CONT_QUO_VOT=""
    KAFKA_SERVERS=""
    KAFKA_PORT=9092
    for WORKER_i in $WORKERS; do
      KAFKA_SERVERS+="${NODE_ID}@${WORKER_i}:${KAFKA_PORT},"
      ((NODE_ID = NODE_ID + 1))
    done
    export KAFKA_SERVERS=${KAFKA_SERVERS%,}

    sed -i 's|KAFKA_SERVER_ALL|'$KAFKA_SERVERS'|g' "$KAFKA_CONFIG_SERVER_FILE"
    NODE_ID=1
    for WORKER_i in $WORKERS; do
      KAFKA_CONFIG_SERVER_FILE_i="${KAFKA_CONF_DIR}/${WORKER_i}.properties"
      cp "$KAFKA_CONFIG_SERVER_FILE" "$KAFKA_CONFIG_SERVER_FILE_i"
      sed -i 's|KAFKA_SERVER_HOSTNAME|'$KAFKA_SOURCE_HOST'|g' "$KAFKA_CONFIG_SERVER_FILE_i"
      sed -i 's|NODE_ID|'$NODE_ID'|g' "$KAFKA_CONFIG_SERVER_FILE_i"
      ((NODE_ID = NODE_ID + 1))
    done
  fi
fi
