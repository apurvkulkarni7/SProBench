#!/bin/bash
set -e

check_file CONF_FILE_RUN
check_var SPB_SYSTEM
check_var FRAMEWORK
check_directory BENCHMARK_DIR

# Mapping sparkstrucstream -> spark
if [[ $FRAMEWORK =~ (sparkstrucstream|SPARKSTRUCSTREAM) ]]; then
  FRAMEWORK_MAIN='spark'
else
  FRAMEWORK_MAIN=$FRAMEWORK
fi
export FRAMEWORK_MAIN_L=${FRAMEWORK_MAIN,,}
export FRAMEWORK_MAIN_U=${FRAMEWORK_MAIN^^}

case ${SPB_SYSTEM} in

localmachine)
  # Loading core frameworks
  CORE_FRAMEWORKS="java maven kafka"
  for CORE_FRAMEWORK_i in $CORE_FRAMEWORKS; do
    CORE_FRAMEWORK_HOME=$($YQ '.frameworks.'${CORE_FRAMEWORK_i,,}'.local_setup.path' $INIT_CONF_FILE)
    if [[ ${CORE_FRAMEWORK_HOME} == 'default' ]]; then CORE_FRAMEWORK_HOME="${BENCHMARK_DIR}/frameworks/${CORE_FRAMEWORK_i,,}"; fi
    export ${CORE_FRAMEWORK_i^^}_HOME=${CORE_FRAMEWORK_HOME}
  done

  # loading stream processing
  FRAMEWORK_HOME=$($YQ '.frameworks.'${FRAMEWORK_MAIN_L}'.local_setup.path' $CONF_FILE_RUN)
  if [[ $FRAMEWORK_HOME == 'default' ]]; then FRAMEWORK_HOME="${BENCHMARK_DIR}/frameworks/${FRAMEWORK_MAIN_L}";  fi
  export ${FRAMEWORK_MAIN_U}_HOME=$FRAMEWORK_HOME

  ;;

slurm_interactive | slurm_batch)

  # Reset modules
  module purge >/dev/null 2>&1
  module reset >/dev/null 2>&1

  # Use moudles installed on custom path
  CUSTOM_MODULE_PATHS=$(eval echo $($YQ '.frameworks.custom_module_path | .[]' $CONF_FILE_RUN))
  for CUSTOM_PATH_i in $CUSTOM_MODULE_PATHS; do
    logger_info "Adding custom module path to the MODULEPATH"
    for i in $(find $CUSTOM_PATH_i -type d); do
      module use $i
    done
  done

  logger_info "Loading core modules"
  CORE_FRAMEWORKS="java maven kafka"
  for CORE_FRAMEWORK_i in $CORE_FRAMEWORKS; do
    load_modules \
      $($YQ '.frameworks["'"${CORE_FRAMEWORK_i}"'"].slurm_setup.dependent_modules[]' $CONF_FILE_RUN)

    load_modules \
      $($YQ '.frameworks["'"${CORE_FRAMEWORK_i}"'"].slurm_setup.module_name_version' $CONF_FILE_RUN)
  done

  # Load stream processing framework
  if [[ "$FRAMEWORK_MAIN_L" != "messagebroker" ]]; then
    logger_info "Loading stream processing framework (${FRAMEWORK_MAIN_L}) module."
    load_modules $($YQ '.frameworks["'"${FRAMEWORK_MAIN_L}"'"].slurm_setup.module_name_version' $CONF_FILE_RUN)
  fi
  # Set some environment variables
  if [[ -z $JAVA_HOME ]]; then
    logger_error "Java module not loaded correctly."
    exit 1
  fi
  if command which mvn >/dev/null 2>&1; then
    MVN_HOME=$(dirname $(dirname $(which mvn)))
  else
    logger_error "Maven module not loaded correctly."
  fi

  [[ $(check_var KAFKA_HOME) ]] && logger_error "Kafka module not available." && exit 1

  case ${FRAMEWORK_MAIN_L} in
  flink)
    ((check_var FLINK_ROOT_DIR 2>&1 > /dev/null) || (check_var FLINK_HOME 2>&1 >/dev/null)) || \
      { logger_error "Flink module not loaded correctly." && exit 1; }
    export FLINK_HOME=${FLINK_HOME:-$FLINK_ROOT_DIR}
    ;;
  spark)
    check_var SPARK_HOME || logger_error "Spark module not loaded correctly." && exit 1
    ;;
  esac
  ;;
esac

# Set core environment variables
export JAVA="${JAVA_HOME}/bin/java"
export MVN="${MVN_HOME}/bin/mvn"