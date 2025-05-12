#!/bin/bash
set -e

check_var SPB_SYSTEM
check_var FRAMEWORK
check_var FRAMEWORK_MAIN_L
check_var FRAMEWORK_MAIN_U

# Copy configuration from template directory
case $SPB_SYSTEM in
localmachine)
  cp -r $FRAMEWORK_CONFIG_TEMPLATE_KAFKA $LOG_DIR_RUN_CONFIG/
  case $FRAMEWORK_MAIN_L in
  flink) cp -r $FRAMEWORK_CONFIG_TEMPLATE_FLINK $LOG_DIR_RUN_CONFIG/ ;;
  spark) cp -r $FRAMEWORK_CONFIG_TEMPLATE $LOG_DIR_RUN_CONFIG/ ;;
  esac
  #NODE_LIST="localhost"
  NODE_LIST=$(hostname)
  ;;
slurm_interactive | slurm_batch)
  source framework-configure.sh --framework kafka --template $FRAMEWORK_CONFIG_TEMPLATE_KAFKA --destination $LOG_DIR_RUN_CONFIG

  if [[ "$FRAMEWORK_MAIN_L" != "messagebroker" ]]; then
    # Initialize framework configuration
    FRAMEWORK_CONFIG_TEMPLATE="FRAMEWORK_CONFIG_TEMPLATE_${FRAMEWORK_MAIN_U}" # Construct the variable name
    source framework-configure.sh --framework ${FRAMEWORK_MAIN_L} --template ${!FRAMEWORK_CONFIG_TEMPLATE} --destination $LOG_DIR_RUN_CONFIG
  fi

  NODE_LIST=$(scontrol show hostname $SLURM_NODELIST | sort -u)
  ;;
esac
export NODE_LIST=($NODE_LIST)

# export ARCHITECTURE_TYPE=0
logger_info "Total available nodes: ${NODE_LIST[*]}"

#################################################################
# Framework env configuration
#################################################################
if [[ "$FRAMEWORK_MAIN_L" != "messagebroker" ]]; then
case $FRAMEWORK_MAIN_L in
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
kafkastream)
  export FRAMEWORK_MASTER="${NODE_LIST[0]}"
  case $SPB_SYSTEM in
  localmachine)
    export FRAMEWORK_WORKERS="$FRAMEWORK_MASTER"
    export FRAMEWORK_WORKERS_NUM="$NUM_WORKERS"
    #export FRAMEWORK_SLOTS_PER_TASKMANAGER="$NUM_CPU_WORKERS"
    export FRAMEWORK_PARALLELISM_PER_WORKER="$NUM_CPU_WORKERS"
    export FRAMEWORK_PARALLELISM=$((FRAMEWORK_PARALLELISM_PER_WORKER * FRAMEWORK_WORKERS_NUM))
    export FRAMEWORK_MEM_MASTER="$MEM_MASTER"
    export FRAMEWORK_MEM_PER_WORKER="$MEM_NODE_WORKER"
    export FRAMEWORK_MEM_PER_WORKER_SPARE="$MEM_NODE_WORKER_SPARE"
    ;;
  slurm_interactive | slurm_batch)
    export FRAMEWORK_WORKERS_NUM="$NUM_WORKERS"
    if [[ "${#NODE_LIST[@]}" -eq 1 ]]; then
      #if [[ "${FRAMEWORK_WORKERS_NUM}" -eq 1 ]]; then
      # current setup
      #            -------------------------------------------------------
      # Node1      | Generator, Kafka broker, Flink Master, Flink worker |
      #            -------------------------------------------------------
      export FRAMEWORK_WORKERS="$FRAMEWORK_MASTER"
    else
      # this setup
      #            ------------------------------------------
      # Node1      |  Generator, Kafka broker, Flink Master |
      #            ------------------------------------------
      #            -----------------  -----------------
      # Node 2..x  | Flink Worker1 |  | Flink Worker2 |  ...
      #            -----------------  -----------------
      #
      #export FRAMEWORK_WORKERS_TMP=${NODE_LIST[@]:1} # Removing 1st node
      export FRAMEWORK_WORKERS=${NODE_LIST[@]:1} # Removing 1st node
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
    export FRAMEWORK_PARALLELISM_PER_WORKER=$NUM_CPU_WORKERS
    #      tmp_sptm=$FRAMEWORK_SLOTS_PER_TASKMANAGER
    #      ((tmp_sptm=tmp_sptm-SPARE_CORES_PER_NODE))
    #      if [[ "${tmp_sptm}" -lt "1" ]]; then
    #          echo "No CPUs available for taskmanager. Allocate higher CPUs or reduces spare CPUs"
    #          echo "Available CPUs/node: ${SLURM_CPUS_ON_NODE}"
    #          echo "CPUs/node allocated for Taskmanager: ${tmp_sptm}"
    #          exit 1
    #      fi
    #export FRAMEWORK_SLOTS_PER_TASKMANAGER=${FRAMEWORK_SLOTS_PER_TASKMANAGER:-$tmp_sptm}
    #export FRAMEWORK_PARALLELISM=${FRAMEWORK_PARALLELISM:-$((${#FRAMEWORK_WORKERS_NUM[@]}*$FRAMEWORK_SLOTS_PER_TASKMANAGER))}
    export FRAMEWORK_PARALLELISM=$((FRAMEWORK_SLOTS_PER_TASKMANAGER * FRAMEWORK_WORKERS_NUM))

    export FRAMEWORK_MEM_MASTER="${MEM_MASTER}"
    export FRAMEWORK_MEM_PER_WORKER="${MEM_NODE_WORKER}"
    export FRAMEWORK_MEM_PER_WORKER_SPARE="${MEM_NODE_WORKER_SPARE}"

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
      export FRAMEWORK_MEM_NODE_WORKER="${taskmanager_memory}G" # This is used only when a single taskmanager/node is used
    fi
    ;;
  esac
  check_directory LOG_DIR_RUN_LOG_FRAMEWORK
  #check_directory LOG_DIR_RUN_CONFIG_FRAMEWORK # not required for kafkastream
  export FRAMEWORK_MASTER_FILE="$LOG_DIR_RUN_CONFIG_FRAMEWORK/masters"
  export FRAMEWORK_WORKERS_FILE="$LOG_DIR_RUN_CONFIG_FRAMEWORK/workers"
  export FRAMEWORK_CONF_YAML_FILE="$LOG_DIR_RUN_CONFIG_FRAMEWORK/flink-conf.yaml"
  ;;
spark)
  export FRAMEWORK_MASTER="${NODE_LIST[0]}"
  case $SPB_SYSTEM in
  localmachine)
    export FRAMEWORK_WORKERS="$FRAMEWORK_MASTER"
    export FRAMEWORK_WORKERS_NUM="$NUM_WORKERS"
    export FRAMEWORK_SLOTS_PER_TASKMANAGER="$NUM_CPU_WORKERS"
    export FRAMEWORK_PARALLELISM_PER_WORKER="$NUM_CPU_WORKERS"
    export FRAMEWORK_PARALLELISM=$((FRAMEWORK_PARALLELISM_PER_WORKER * FRAMEWORK_WORKERS_NUM))
    export FRAMEWORK_MEM_MASTER="$MEM_MASTER"
    export FRAMEWORK_MEM_PER_WORKER="$MEM_NODE_WORKER"
    export FRAMEWORK_MEM_PER_WORKER_SPARE="$MEM_NODE_WORKER_SPARE"
    ;;
  slurm_interactive | slurm_batch)
    export FRAMEWORK_WORKERS_NUM="$NUM_WORKERS"
    if [[ "${#NODE_LIST[@]}" -eq 1 ]]; then
      export FRAMEWORK_WORKERS="$FRAMEWORK_MASTER"
    else
      export FRAMEWORK_WORKERS=${NODE_LIST[@]:1}
    fi
    export FRAMEWORK_PARALLELISM_PER_WORKER=$NUM_CPU_WORKERS
    export FRAMEWORK_PARALLELISM=$((FRAMEWORK_PARALLELISM_PER_WORKER * FRAMEWORK_WORKERS_NUM))
    export FRAMEWORK_MEM_MASTER="${MEM_MASTER}"
    export FRAMEWORK_MEM_PER_WORKER="${MEM_NODE_WORKER}"
    export FRAMEWORK_MEM_PER_WORKER_SPARE="${MEM_NODE_WORKER_SPARE}"

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
      export FRAMEWORK_MEM_NODE_WORKER="${taskmanager_memory}G" # This is used only when a single taskmanager/node is used
    fi
    ;;
  esac
  check_directory LOG_DIR_RUN_LOG_FRAMEWORK
  check_directory LOG_DIR_RUN_CONFIG_FRAMEWORK # not required for kafkastream
  export FRAMEWORK_MASTER_FILES=(
    "$LOG_DIR_RUN_CONFIG_FRAMEWORK/spark-submit"
    "$LOG_DIR_RUN_CONFIG_FRAMEWORK/spark-env.sh"
    "$LOG_DIR_RUN_CONFIG_FRAMEWORK/spark-defaults.conf"
  )
  export FRAMEWORK_WORKERS_FILE="$LOG_DIR_RUN_CONFIG_FRAMEWORK/workers"
  export FRAMEWORK_CONF_FILES=(
    "$LOG_DIR_RUN_CONFIG_FRAMEWORK/spark-defaults.conf"
    "${LOG_DIR_RUN_CONFIG_FRAMEWORK}/spark-env.sh"
    "${LOG_DIR_RUN_CONFIG_FRAMEWORK}/log4j2.properties"
    )
  export ${FRAMEWORK_MAIN_U}_CONF_DIR="$LOG_DIR_RUN_CONFIG_FRAMEWORK"
  ;;
esac
fi
#################################################################
# Kafka configuration
#################################################################
check_var KAFKA_SOURCE_TOPICS
check_var KAFKA_SINK_TOPICS
KAFKA_SOURCE_PARTITION_NUM=$($YQ '.kafka.source_topics[].num_partition' $CONF_FILE_RUN)
if [[ $KAFKA_SOURCE_PARTITION_NUM == 'processor' ]]; then
  export KAFKA_SOURCE_PARTITION_NUM="${NUM_CPU_WORKERS}"
fi

KAFKA_SINK_PARTITION_NUM=$($YQ '.kafka.sink_topics[].num_partition' $CONF_FILE_RUN)
if [[ $KAFKA_SINK_PARTITION_NUM == 'processor' ]]; then
  export KAFKA_SINK_PARTITION_NUM="${NUM_CPU_WORKERS}"
fi

check_directory LOG_DIR_RUN_LOG_KAFKA
export LOG_DIR="$LOG_DIR_RUN_LOG_KAFKA"
export KAFKA_LOG4J_OPTS_GEN="-Dlog4j.configuration=file:$LOG_DIR_RUN_CONFIG_KAFKA/log4j.properties"
export KAFKA_LOG4J_OPTS="$KAFKA_LOG4J_OPTS_GEN"
export KAFKA_LOG4J_OPTS_TOPIC="-Dlog4j.configuration=file:$LOG_DIR_RUN_CONFIG_KAFKA/tools-log4j.properties"

check_directory LOG_DIR_RUN_CONFIG_KAFKA
export KAFKA_CONFIG_SERVER_FILE="$LOG_DIR_RUN_CONFIG_KAFKA/kraft/server.properties"
export KAFKA_CONFIG_PRODUCER_PROP_FILE="$LOG_DIR_RUN_CONFIG_KAFKA/producer.properties"
TMP_DIR=$($YQ '.tmp_dir' $CONF_FILE_RUN)
export KAFKA_LOG_DIR="${TMP_DIR}/${USER}/${SLURM_JOBID}/$LOG_DIR_RUN_LOG_KAFKA/kafka-logs" # this is different from actual logging directory

case $SPB_SYSTEM in
localmachine)
  # Kafka configuration
  export KAFKA_SOURCE_HOST=$(hostname)
  export KAFKA_SOURCE_PORT="9092"
  export KAFKA_SOURCE_BOOTSTRAP_SERVER="${KAFKA_SOURCE_HOST}:${KAFKA_SOURCE_PORT}"
  export KAFKA_SINK_HOST=$(hostname)
  export KAFKA_SINK_PORT="9092"
  export KAFKA_SINK_BOOTSTRAP_SERVER="${KAFKA_SINK_HOST}:${KAFKA_SINK_PORT}"
  export KAFKA_CONF_DIR="$LOG_DIR_RUN_CONFIG_KAFKA"
  ;;
slurm_interactive | slurm_batch)
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
  ;;
esac
