#!/bin/bash
set -e

function runner_usage() {
# Help section
  local type
  type=$1

  echo "Usage: runner.sh -t <TYPE> [-d DIRECTORY] [-c CONFIG_FILE] [-m START|STOP]"
  echo ""
  
  if [[ "$type" == "long" ]]; then
    echo "Description:"
    echo "This script starts or stops various types of applications based on the specified type, directory, and configuration file."
    echo ""
    echo "Options:"
    echo "-t (required): The type of application to start or stop. Possible values: GENERTOR, FLINK, SPARK-STREAMING, KAFKASTREAMING"
    echo "-d (optional): The directory where experiment data will be stored"
    echo "-c (optional): The path to the experiment main configuration file"
    echo "-m (optional): The execution mode. Possible values: START(default), STOP"
    echo ""
  fi
}

function runner_input_parser() {
  # Parse command-line arguments using getopt
  if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    runner_usage long
    exit 0
    break
  fi
  
  local short_opt=":t:d:c:m:h:"
  local long_opt=":type:dir:conf:mode:"
  
  while getopts "$short_opt" opt; do
    # Check for required options
    if [ -z "$FRAMEWORK" ]; then
      case $opt in
        t)
          if [[ "$OPTARG" != "CHECK" ]] &&\
             [[ "$OPTARG" != "GENERATOR" ]] &&\
             [[ "$OPTARG" != "FLINK" ]] &&\
             [[ "$OPTARG" != "SPARK_STREAMING" ]] &&\
             [[ "$OPTARG" != "KAFKA_STREAM" ]]; then
                echo "Invalid value for -t (type): $OPTARG" >&2
                echo "For more info: $0 --help"
                exit 1
          fi
          export FRAMEWORK="$OPTARG"
          ;;
      esac
    fi
    # Optional parameters
    case $opt in
      d)
        LOG_DIR_MAIN="$OPTARG"
        if [[ "x$LOG_DIR_MAIN" != "x" ]]; then
          LOG_DIR_MAIN=$(realpath $LOG_DIR_MAIN)
        fi
        ;;
      c)
        INIT_CONF_FILE="$OPTARG"
        if [[ "x$INIT_CONF_FILE" != "x" ]]; then
          INIT_CONF_FILE=$(realpath $INIT_CONF_FILE)
        fi
        ;;
      m)
        MODE="$OPTARG"
        ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
        runner_usage
        exit 1
        ;;
    esac
  done
   if [ -z "$FRAMEWORK" ]; then
    echo "Missing -t option" >&2
    runner_usage
    exit 1
  fi
  if [ -z "$LOG_DIR_MAIN" ]; then
    export LOG_DIR_MAIN=$(realpath $(dirname $0))/tmp
    #echo "Missing -d option" >&2
    if [[ $FRAMEWORK != "CHECK" ]]; then
      echo "Using default directory: $LOG_DIR_MAIN" >&2
    fi
  fi
  if [ -z "$INIT_CONF_FILE" ]; then
    export INIT_CONF_FILE=$(realpath $(dirname $0))/default_config.yaml 
    #echo "Missing -c option" >&2
    echo "Using default configuration file: $INIT_CONF_FILE" >&2
  fi
  if [ -z "$MODE" ]; then
    #echo "Missing -m option" >&2
    if [[ $FRAMEWORK != "CHECK" ]]; then
      echo "Using default mode: START" >&2
    fi
    export MODE=START
  fi
}
