#!/bin/bash
set -e

check_file CONF_FILE_RUN
check_var SPB_SYSTEM
check_var FRAMEWORK

case ${SPB_SYSTEM} in

localmachine)

  export JAVA_HOME=$($YQ '.frameworks.java.local_setup.path' $CONF_FILE_RUN)
  export MVN_HOME=$($YQ '.frameworks.maven.local_setup.path' $CONF_FILE_RUN)
  export KAFKA_HOME=$($YQ '.frameworks.kafka.local_setup.path' $CONF_FILE_RUN)

  export ${FRAMEWORK^^}_HOME=$($YQ ".frameworks.${FRAMEWORK,,}.local_path" $CONF_FILE_RUN)
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
  logger_info "Loading stream processing framework (${FRAMEWORK,,}) module."
  load_modules $($YQ '.frameworks["'"${FRAMEWORK,,}"'"].slurm_setup.module_name_version' $CONF_FILE_RUN)

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
  
  case ${FRAMEWORK,,} in
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