#!/bin/bash
set -e

function print_usage() {
  # Help section
  local type=$1

  echo "Usage: runner.sh <-o DIRECTORY> [-cf CONFIG_FILE] [-m START|STOP]"
  echo ""
  if [[ "$type" == "long" ]]; then
    echo "Description:"
    echo "This script starts or stops various types of applications based on the specified type, directory, and configuration file."
    echo ""
    echo "Options:"
    #echo "-t (required): The type of application to start or stop. Possible values: GENERTOR, FLINK, SPARK-STREAMING, KAFKASTREAMING"
    echo "--system_type, -s    : The system type"
    echo "--output_dir, -o    : The directory where experiment data will be stored"
    echo "--conf_file, -c  : The path to the experiment main configuration file."
    echo "--mode, -m          : The execution mode. Possible values: START(default), STOP"
    echo ""
  fi
}

if [[ "$#" -lt "3" ]]; then
  logger_error "Not enough arguments are provided."
  print_usage "long"
  return 1
else
  # Default values
  if ! [[ $@ =~ (--conf_file|-c) ]]; then
    SPB_DEFAULT_CONF_FILE="$(realpath $(dirname $0))/utils/configs/default_config.yaml"
    logger_info "Using default configuration file (${SPB_DEFAULT_CONF_FILE})."
    export INIT_CONF_FILE="${SPB_DEFAULT_CONF_FILE}"
  fi
  if ! [[ $@ =~ (--mode|-m) ]]; then
    logger_info "Using default mode: START"
    export MODE="START"
  fi

  while [ $# -gt 0 ]; do
    arg="$1"
    case "$arg" in
    '--help' | '-h')
      print_usage
      return 0
      ;;
    '--output_dir' | '-o')
      if [[ "${2:-not_set}" == "not_set" ]]; then
        logger_error "No output directory specified."
        return 1
      elif [ ! -d "${2:-'/does/not/exist'}" ]; then
        logger_error "Please provide valid existing directory with parameter \"$arg\"".
        return 1
      fi
      export LOG_DIR_MAIN="$(realpath $2)"
      shift
      ;;
    '--setup')
      SETUP="true"
      ;;
    '--mode' | '-m')
      if [[ "${2:-'not_set'}" == "not_set" ]]; then
        logger_error "Please provide valid mode with parameter \"$arg\"".
        return 1
      fi
      if [[ "$2" =~ ^(START|STOP)$ ]]; then
      export MODE=$2
      fi
      shift
      ;;
    '--conf_file' | '-c')
      if [[ "${2:-not_set}" == "not_set" ]] || [ ! -f "$2" ]; then
        logger_error "Please provide valid existing configuration file with parameter \"$arg\"".
        return 1
      fi
      export INIT_CONF_FILE=$(realpath $2)
      shift
      ;;
    '--system_type' | '-s')
      # We need this because we want get this info on run time for compilation and for starting slurm jobs
      if [[ "${2:-not_set}" == "not_set" ]] || ! [[ "$2" =~ ^(localmachine|slurm_interactive|slurm_batch)$ ]]; then
        logger_error "Please provide valid system with parameter \"$arg\""
        return 1
      fi
      export SPB_SYSTEM=$2
      logger_info "Running benchmark on $2 setup".
      shift
      ;;
    -*)
      logger_error "Unsupported parameter \"$arg\" used."
      return 1
      ;;
    *)
      print_usage
      return 1
      ;;
    esac
    shift
  done
fi

if [[ "$SETUP" == "true" ]]; then
  utils/setup_benchmark.sh $SPB_SYSTEM $INIT_CONF_FILE
fi