#!/bin/bash
set -e

export LOG_DIR_RUN=$1
mkdir -p $LOG_DIR_RUN

TEST_TYPE=$2
INIT_CONF_FILE=$3

if [[ "${ONLY_DATA_GENERATOR}" == "true" ]]; then
  FRAMEWORK="generator"
fi

case ${FRAMEWORK,,} in
flink)
#if [[ "$TEST_TYPE" == "FLINK" ]]; then

  export LOG_DIR_RUN_LOG="${LOG_DIR_RUN}/log"; mkdir -p "$LOG_DIR_RUN_LOG"
  export LOG_DIR_RUN_LOG_FLINK="${LOG_DIR_RUN_LOG}/flink";mkdir -p "$LOG_DIR_RUN_LOG_FLINK"
  export LOG_DIR_RUN_LOG_FLINK_EVENTS_HIST="${LOG_DIR_RUN_LOG_FLINK}/events-history"; mkdir -p "$LOG_DIR_RUN_LOG_FLINK_EVENTS_HIST"
  export LOG_DIR_RUN_LOG_KAFKA="${LOG_DIR_RUN_LOG}/kafka";mkdir -p "$LOG_DIR_RUN_LOG_KAFKA"
  export LOG_DIR_RUN_LOG_GENERATOR="${LOG_DIR_RUN_LOG}/generator";mkdir -p "$LOG_DIR_RUN_LOG_GENERATOR"
  export LOG_DIR_RUN_LOG_JMX="${LOG_DIR_RUN_LOG}/jmx";mkdir -p "$LOG_DIR_RUN_LOG_JMX"

  export FRAMEWORK_CONFIG_TEMPLATE="$BENCHMARK_DIR/framework-config-template"
  export FRAMEWORK_CONFIG_TEMPLATE_KAFKA="$FRAMEWORK_CONFIG_TEMPLATE/kafka"
  export FRAMEWORK_CONFIG_TEMPLATE_FLINK="$FRAMEWORK_CONFIG_TEMPLATE/flink"

  export LOG_DIR_RUN_CONFIG="${LOG_DIR_RUN}/config"; mkdir -p "$LOG_DIR_RUN_CONFIG"

  export LOG_DIR_RUN_CONFIG_FLINK="${LOG_DIR_RUN_CONFIG}/flink"; # mkdir -p "$LOG_DIR_RUN_CONFIG_FLINK"
  export LOG_DIR_RUN_CONFIG_KAFKA="${LOG_DIR_RUN_CONFIG}/kafka"; # mkdir -p "$LOG_DIR_RUN_CONFIG_KAFKA"
  ;;
message_broker|generator)
# elif [[ "$TEST_TYPE" == "GENERATOR" ]]; then

  export LOG_DIR_RUN_LOG="${LOG_DIR_RUN}/log"; mkdir -p "$LOG_DIR_RUN_LOG"
  export LOG_DIR_RUN_LOG_KAFKA="${LOG_DIR_RUN_LOG}/kafka";mkdir -p "$LOG_DIR_RUN_LOG_KAFKA"
  export LOG_DIR_RUN_LOG_GENERATOR="${LOG_DIR_RUN_LOG}/generator";mkdir -p "$LOG_DIR_RUN_LOG_GENERATOR"
  export LOG_DIR_RUN_LOG_JMX="${LOG_DIR_RUN_LOG}/jmx";mkdir -p "$LOG_DIR_RUN_LOG_JMX"

  export FRAMEWORK_CONFIG_TEMPLATE="$BENCHMARK_DIR/framework-config-template"
  export FRAMEWORK_CONFIG_TEMPLATE_KAFKA="$FRAMEWORK_CONFIG_TEMPLATE/kafka"

  export LOG_DIR_RUN_CONFIG="${LOG_DIR_RUN}/config"; mkdir -p "$LOG_DIR_RUN_CONFIG"
  export LOG_DIR_RUN_CONFIG_KAFKA="${LOG_DIR_RUN_CONFIG}/kafka"; # mkdir -p "$LOG_DIR_RUN_CONFIG_KAFKA"
  ;;
# fi
esac
# Copying yaml config
cp "$INIT_CONF_FILE" "$LOG_DIR_RUN_CONFIG/config.yaml"
export CONF_FILE_RUN="$LOG_DIR_RUN_CONFIG/config.yaml"

