#!/bin/bash
set -e
set -o errtrace
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

kafka_tool_wrapper() {
  cmd=$1
  shift 1
  KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:$KAFKA_CONF_DIR/tools-log4j.properties" \
    "$KAFKA_HOME/bin/${cmd}" "$@"
}

HOST=${1:-"localhost"}
export KAFKA_CONF_DIR=$2
LOG_DIR=$3

CURR_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source "${CURR_DIR}/../init.sh"

if [[ $SPB_SYSTEM =~ slurm_* ]]; then  
  load_modules "release/24.04" "GCC/13.2.0" "Kafka/3.6.1-scala-2.13"
fi

KAFKA_CLUSTER_ID_FILE="${KAFKA_CONF_DIR}/kafka_cluster_id"
# if [[ ! -f "${KAFKA_CLUSTER_ID_FILE}" ]];then
kafka_tool_wrapper kafka-storage.sh random-uuid | awk '{print $NF}' > "${KAFKA_CLUSTER_ID_FILE}"
# fi
KAFKA_CLUSTER_ID="$(cat "${KAFKA_CLUSTER_ID_FILE}")"

KAFKA_SERVER_FILE="${KAFKA_CONF_DIR}/${HOST}.properties"
# Format the storage
kafka_tool_wrapper kafka-storage.sh format -t "${KAFKA_CLUSTER_ID}" -c "${KAFKA_SERVER_FILE}" > "${LOG_DIR}/kafka-server-start_${HOST}.log" 2>&1

# Start the cluster
export KAFKA_HEAP_OPTS="-Xms5g -Xmx5g"
export KAFKA_JVM_PERFORMANCE_OPTS="-XX:+UseG1GC -server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+DisableExplicitGC -Djava.awt.headless=true"
#export KAFKA_JVM_PERFORMANCE_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -XX:G1HeapRegionSize=16M -XX:MetaspaceSize=96m -XX:MinMetaspaceFreeRatio=50 -XX:MaxMetaspaceFreeRatio=80"
"$KAFKA_HOME"/bin/kafka-server-start.sh -daemon "${KAFKA_SERVER_FILE}" >> "${LOG_DIR}/kafka-server-start_${HOST}.log" 2>&1

wait_until_process_started "Kafka"
create_pid_file "Kafka" "${LOG_DIR}/kafka_cluster_${HOST}.pid"