#!/bin/bash
# setup_framework_config.sh [FLINK|SPARK]
set -e

FRAMEWORK=$1

if [[ "$FRAMEWORK" == "FLINK" ]]; then
  check_directory FLINK_CONF_DIR
  
  # Create/overwrite master file
  check_file FLINK_MASTER_FILE
  echo "$FLINK_MASTER:8081" > "${FLINK_MASTER_FILE}"

  # create workers file with every available node
  check_var FLINK_WORKERS
  FLINK_WORKERS=($FLINK_WORKERS)
  check_file FLINK_WORKERS_FILE
  echo "$(printf '%s\n' "${FLINK_WORKERS[@]}")" > $FLINK_WORKERS_FILE

  # flink-conf.yaml
  check_file FLINK_CONF_YAML_FILE
  # Set master node
  check_var FLINK_MASTER
  sed -i 's|FLINK_MASTER_HOSTNAME|'$FLINK_MASTER'|g' "$FLINK_CONF_YAML_FILE"

  # Parallelism and Slots offered
  check_var FLINK_SLOTS_PER_TASKMANAGER
  sed -i 's|FLINK_SLOTS_PER_TASKMANAGER|'$FLINK_SLOTS_PER_TASKMANAGER'|g' "${FLINK_CONF_YAML_FILE}"
  check_var FLINK_PARALLELISM
  sed -i 's|FLINK_PARALLELISM|'$FLINK_PARALLELISM'|g' $FLINK_CONF_YAML_FILE

  # Memory configuration
  # All memory is in 'G' (G)
  check_var FLINK_MEM_MASTER
  check_var FLINK_MEM_PER_WORKER
  sed -i 's|FLINK_MEM_MASTER|'$FLINK_MEM_MASTER'|g' "$FLINK_CONF_YAML_FILE"
  sed -i 's|FLINK_MEM_PER_WORKER|'$FLINK_MEM_PER_WORKER'|g' "$FLINK_CONF_YAML_FILE"

  # Generate events history
  check_directory FLINK_LOG_DIR
  sed -i 's|FLINK_LOG_DIR|'$FLINK_LOG_DIR'|g' "$FLINK_CONF_YAML_FILE"

  # Java env variables env.java.home:
  check_var JAVA_HOME
  sed -i 's|JAVA_HOME|'$JAVA_HOME'|g' "$FLINK_CONF_YAML_FILE"

  # Logging interval
  check_var METRIC_LOGGING_INTERVAL_SEC
  sed -i 's|METRIC_LOGGING_INTERVAL_SEC|'METRIC_LOGGING_INTERVAL_SEC'|g' "$FLINK_CONF_YAML_FILE"
fi
#----------------------------------------------------------------------
# Kafka configuration
#----------------------------------------------------------------------
check_file KAFKA_CONFIG_SERVER_FILE
check_var KAFKA_SINK_PARTITION_NUM
sed -i 's|KAFKA_LOG_DIR|'$KAFKA_LOG_DIR'|g' "$KAFKA_CONFIG_SERVER_FILE"
sed -i 's|KAFKA_PARTITION_NUM|'$KAFKA_SOURCE_PARTITION_NUM'|g' "$KAFKA_CONFIG_SERVER_FILE"

sed -i 's|^.*\(export LOG_DIR=\).*$|\1'$LOG_DIR_RUN_LOG_KAFKA'|g' "$LOG_DIR_RUN_CONFIG_KAFKA/setup-kafka-env.sh"
sed -i 's|^.*\(export JAVA_HOME=\).*$|\1'$JAVA_HOME'|g' "$LOG_DIR_RUN_CONFIG_KAFKA/setup-kafka-env.sh"

# Kafka architecture
#   1: single node setup. Kafka on master node
#   2: Single/multi node setup. Kafka on worker node (different node than master node)

if [[ "${KAFKA_ARCH}" == "1" ]] || [[ ! $(is_hpc) ]]; then
  NODE_ID=1
  sed -i 's|KAFKA_SERVER_HOSTNAME|'$KAFKA_SOURCE_HOST'|g' "$KAFKA_CONFIG_SERVER_FILE"
  sed -i 's|NODE_ID|'$NODE_ID'|g' "$KAFKA_CONFIG_SERVER_FILE"
  sed -i 's|KAFKA_SERVER_ALL$|'"$NODE_ID@$KAFKA_SOURCE_BOOTSTRAP_SERVER"'|g' "$KAFKA_CONFIG_SERVER_FILE"
  sed -i 's|KAFKA_CONTROLLER_SERVER_ALL$|'"$NODE_ID@$KAFKA_SOURCE_HOST:9093"'|g' "$KAFKA_CONFIG_SERVER_FILE"
  cp "$KAFKA_CONFIG_SERVER_FILE" "${LOG_DIR_RUN_CONFIG_KAFKA}/${KAFKA_SOURCE_HOST}.properties"
elif [[ "${KAFKA_ARCH}" == "2" ]]; then
  
  WORKERS="$FLINK_WORKERS"
  NODE_ID=1
  TMP_CONT_QUO_VOT=""
  for WORKER_i in $WORKERS; do
    TMP_CONT_QUO_VOT="${TMP_CONT_QUO_VOT}${NODE_ID}@${WORKER_i}:9093"
    ((NODE_ID=NODE_ID+1))
  done
  sed -i 's|KAFKA_SERVER_ALL|'$TMP_CONT_QUO_VOT'|g' "$KAFKA_CONFIG_SERVER_FILE"
  NODE_ID=1
  for WORKER_i in $WORKERS; do
    KAFKA_CONFIG_SERVER_FILE_i="${KAFKA_CONF_DIR}/${WORKER_i}.properties"
    cp "$KAFKA_CONFIG_SERVER_FILE" "$KAFKA_CONFIG_SERVER_FILE_i"
    sed -i 's|KAFKA_SERVER_HOSTNAME|'$KAFKA_SOURCE_HOST'|g' "$KAFKA_CONFIG_SERVER_FILE_i"
    sed -i 's|NODE_ID|'$NODE_ID'|g' "$KAFKA_CONFIG_SERVER_FILE_i"
    ((NODE_ID=NODE_ID+1))
  done
fi

#Following can be used to launch kafka broker dynamically
#bin/kafka-server-start.sh --override broker.id=1 --override listeners=PLAINTEXT://your.host.name:9092 config/server.properties

# In below sed commands range functionality is used
# source- https://unix.stackexchange.com/questions/432528/using-sed-to-replace-multiline
#sed -i '/^ *kafka.brokers:/,/^ *[^:]*:/s/-.*/- \"'${KAFKA_HOST}'\"/' "conf/benchmarkConf.yaml"