#!/bin/bash
set -e

function print_usage() {
  # Help section
  local type=$1

  echo "Usage: runner.sh [OPTIONS]"
  echo ""
  if [[ "$type" == "long" ]]; then
    echo "Description:"
    echo "  The entry point script that controls the installation and execution"
    echo "  of the benchmark."
    echo ""
    echo "Options:"
    echo "  --setup             Setup the benchmark to install required software"
    echo "                      Requires --system_type and --conf_file."
    echo "  --compile           Compile the benchmark source code."
    echo "                      Requires --system_type and --conf_file"
    echo "  --system_type, -s   The system type where the benchmark is running"
    echo "                      (localmachine, slurm_interactive,slurm_batch)"
    echo "  --output_dir, -o    The directory where benchmark output will be "
    echo "                      stored"
    echo "  --conf_file, -c     The path to the experiment main configuration"
    echo "                      file"
    echo ""
    echo "Usage examples:"
    echo "  Setup   : runner.sh --setup --system_type <type> --conf_file <file>"
    echo "  Compile : runner.sh --compile --system_type <type> --conf_file <file>"
    echo "  Run     : runner.sh --system_type <type> [options]"
    echo ""
  fi
}

HAS_SETUP=0
HAS_SYSTEM_TYPE=0
HAS_CONF_FILE=0
HAS_OUTPUT_DIR=0
HAS_COMPILE=0

while [ $# -gt 0 ]; do
  arg="$1"
  case "$arg" in
  --setup)
    HAS_SETUP=1
    shift
    ;;
  --compile)
    HAS_COMPILE=1
    shift
    ;;
  --system_type | -s)
    if [[ "${2:-not_set}" == "not_set" ]] ||
      ! [[ "$2" =~ ^(localmachine|slurm_interactive|slurm_batch)$ ]]; then
      logger_error "Please provide valid system with parameter \"$arg\""
      exit 1
    fi
    HAS_SYSTEM_TYPE=1
    export SPB_SYSTEM=$2
    logger_info "Running benchmark on $2 setup".
    shift 2
    ;;
  --conf_file | -c)
    if [[ "${2:-not_set}" == "not_set" ]] || [ ! -f "$2" ]; then
      logger_error "Please provide valid existing configuration file with parameter \"$arg\"".
      exit 1
    fi
    HAS_CONF_FILE=1
    export INIT_CONF_FILE=$(realpath $2)
    shift 2
    ;;
  --output_dir | -o)
    if [[ "${2:-not_set}" == "not_set" ]]; then
      logger_error "No output directory specified."
      exit 1
    elif [ ! -d "${2:-'/does/not/exist'}" ]; then
      logger_error "Please provide valid existing directory with parameter \"$arg\"".
      exit 1
    fi
    if [[ ! -w "$2" ]]; then
      echo "Error: Output directory '$2' is not writable." >&2
      exit 1
    fi
    HAS_OUTPUT_DIR=1
    export LOG_DIR_MAIN="$(realpath $2)"
    shift 2
    ;;
  --help | -h)
    print_usage "long"
    exit 0
    ;;
  -*)
    logger_error " Unknown option $1" >&2
    print_usage
    exit 1
    ;;
  *)
    logger_error " Unexpected positional argument $1" >&2
    print_usage
    exit 1
    ;;
  esac
done

export MODE="START" # To be removed later

# Validation checks
if [[ $HAS_SYSTEM_TYPE -eq 0 ]]; then
  logger_error "--system_type is required." >&2
  print_usage
  exit 1
fi

if [[ $HAS_OUTPUT_DIR -eq 0 ]]; then
  export LOG_DIR_MAIN="$(realpath ./tmp)"
  mkdir -p $LOG_DIR_MAIN
  logger_info "Using default output directory (${LOG_DIR_MAIN})."
fi

if [[ $HAS_CONF_FILE -eq 0 ]]; then
  SPB_DEFAULT_CONF_FILE="$(realpath $(dirname $0))/utils/configs/default_config.yaml"
  logger_info "Using default configuration file (${SPB_DEFAULT_CONF_FILE})."
  export INIT_CONF_FILE="${SPB_DEFAULT_CONF_FILE}"
fi

if [[ $HAS_SETUP -eq 1 ]]; then
  utils/install_benchmark.sh $SPB_SYSTEM $INIT_CONF_FILE
  logger_info "Setup complete"
  exit 0
fi

if [[ $HAS_COMPILE -eq 1 ]]; then
  source utils/utils.sh
  case $SPB_SYSTEM in
  localmachine)
    CORE_FRAMEWORKS="java maven"
    for CORE_FRAMEWORK_i in $CORE_FRAMEWORKS; do
      CORE_FRAMEWORK_HOME=$($YQ '.frameworks.'${CORE_FRAMEWORK_i,,}'.local_setup.path' $INIT_CONF_FILE)
      if [[ ${CORE_FRAMEWORK_HOME} == 'default' ]]; then CORE_FRAMEWORK_HOME="${BENCHMARK_DIR}/frameworks/${CORE_FRAMEWORK_i,,}"; fi
      export ${CORE_FRAMEWORK_i^^}_HOME=${CORE_FRAMEWORK_HOME}
    done
    ;;
  slurm_interactive | slurm_batch)
    # Use moudles installed on custom path
    CUSTOM_MODULE_PATHS=$(eval echo $($YQ '.frameworks.custom_module_path | .[]' $INIT_CONF_FILE))
    for CUSTOM_PATH_i in $CUSTOM_MODULE_PATHS; do
      logger_info "Adding custom module path to the MODULEPATH"
      for i in $(find $CUSTOM_PATH_i -type d); do
        module use $i
      done
    done
    logger_info "Loading core modules"
    CORE_FRAMEWORKS="java maven"
    for CORE_FRAMEWORK_i in $CORE_FRAMEWORKS; do
      load_modules \
        $($YQ '.frameworks["'"${CORE_FRAMEWORK_i}"'"].slurm_setup.dependent_modules[]' $INIT_CONF_FILE)

      load_modules \
        $($YQ '.frameworks["'"${CORE_FRAMEWORK_i}"'"].slurm_setup.module_name_version' $INIT_CONF_FILE)
    done
    ;;
  esac
  $MAVEN_HOME/bin/mvn clean package
  logger_info "Compilation complete"
  exit 0
fi
