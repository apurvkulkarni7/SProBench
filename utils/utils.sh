#!/bin/bash
set -e

get_curr_dir() {
  local curr_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
  echo $curr_dir
}

export UTILS_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
export YQ="${UTILS_DIR}/yaml_parser eval"

# These colors are not reflected in Slurm output file.
colblk='' #'\033[0;30m' # Black - Regular
colred='' #'\033[0;31m' # Red
colblu='' #\033[0;32m' # Blue
colylw='' #\033[0;33m' # Yellow
colgrn='' #'\033[0;34m' # Green
colpur='' #\033[0;35m' # Purple
colwht='' #\033[0;97m' # White
colrst='' #\033[0m'    # Text Reset

### verbosity levels
silent_lvl=0
inf_lvl=1
wrn_lvl=2
dbg_lvl=3
err_lvl=4

logger_verbosity="${logger_verbosity:-"1"}"
logger() {
  if [[ "$logger_verbosity" -ge "$logging_lvl" ]] || [[ "$logging_lvl" == "4" ]]; then
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] $@"
  fi
}
logger_info() { logging_lvl=$inf_lvl logger "[${colgrn}INFO${colrst} ] $@"; }
logger_warn() { logging_lvl=$wrn_lvl logger "[${colylw}WARN${colrst} ] $@"; }
logger_debug() { logging_lvl=$dbg_lvl logger "[${colblu}DEBUG${colrst}] $@"; }
logger_error() { logging_lvl=$err_lvl logger "[${colred}ERROR${colrst}] $@"; }

###################################################################################

run_remote_cmd() {
  host=$1
  cmd=$2
  if is_hpc; then
    local jobid=$SLURM_JOBID
    srun --overlap --nodelist="$host" --jobid="$jobid" /bin/bash -c "$cmd"
  else
    eval "$cmd"
  fi
}

print_nodelist() {
  scontrol show hostname $SLURM_NODELIST
}

get_slurm_jobtime() {
  local out=$(squeue -j $SLURM_JOB_ID -h --Format TimeLimit)
  echo $out | awk -F: '{if (NF==2) print "00:" $0; else print $0}'
}

load_modules() {
  modules=$@
  for module_i in $modules; do
    if $(module is-avail $module_i); then
      module is-loaded $module_i || {
        module load $module_i >/dev/null 2>&1
      }
    else
      logger_error "Unable to load module $module_i"
      exit 1
    fi
  done
}

pid_match() {
  local VAL=$(ps -aef | grep "$1" | grep -v grep | awk '{print $2}')
  echo $VAL
}

create_pid_file() {
  process_name=$1
  pid_file=$2
  jps | grep "$process_name" | awk '{print $1}' >"${pid_file}"
}

# Function to check if a process is alive or dead
is_process_alive() {
  local process_name="$1"
  # Get the process ID (PID) of the given process name
  #local pid=$(pgrep -o "$process_name")
  local pid=$(ps -aef | grep -w "$process_name" | grep -v grep | awk '{print $2}')
  if [ -n "$pid" ]; then
    # Process is alive
    return 0
  else
    # Process is dead
    return 1
  fi
}

is_running_pid() {
  local pid_file=$1
  pgrep -F ${pid_file} >/dev/null 2>&1
  return $?
}

# Function to wait until a process is dead
wait_until_process_dead() {
  local process_name="$1"

  # Check if the process is alive
  while is_process_alive "$process_name"; do
    #logger_debug "Waiting for $process_name to exit..."
    sleep 1
  done

  logger_debug "\"$process_name\" is now dead. Proceeding with the script."
}

# Function to wait until a process is started
wait_until_process_started() {
  local process_name="$1"

  # Check if the process is not yet started
  while ! is_process_alive "$process_name"; do
    #logger_debug "Waiting for $process_name to start..."
    sleep 1
  done

  logger_info "\"$process_name\" has started. Proceeding with the script."
  sleep 2s
}

start_if_needed() {
  local match="$1"
  shift
  local name="$1"
  shift
  local sleep_time="$1"
  shift
  local PID=$(pid_match "$match")

  if [[ "$PID" -ne "" ]]; then
    logger_info "$name is already running..."
  else
    "$@" &
    sleep "$sleep_time"
  fi
  logger_info "$name started"
}

stop_if_needed() {
  local match="$1"
  local name="$2"
  local pids=$(pid_match "$match")

  if [ -n "$pids" ]; then
    for pid in $pids; do
      kill "$pid" >/dev/null
      sleep 1s
      logger_info "$name stopped with PID $pid."
    done

    while [ -n "$(pid_match "$match")" ]; do
      for pid in $(pid_match "$match"); do
        kill "$pid" >/dev/null
        sleep 5s
      done
    done
  else
    logger_info "No $name instance found to stop."
  fi
}

# yaml() {
#   if [[ "$1" == "" ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
#     echo "Usage: yaml <my-yaml-file.yaml> <key>"
#     echo "Description:"
#     echo "  key : \"['keystring']\""
#   else
#     #logger_debug "Option provided to  yaml file: $2"
#     $PYTHON -c "import yaml;yaml_data=yaml.safe_load(open('$1'))$2;print('\n'.join(str(i) for i in yaml_data) if type(yaml_data)==list else yaml_data);"
#   fi
# }

# yaml_append() {
#   local OPT_PATH=$1
#   local OPT_VAL=$2
#   local YAML_FILE=$3

#   $PYTHON -c "import yaml;yaml_data=yaml.safe_load(open('$YAML_FILE'));yaml_data$OPT_PATH='$OPT_VAL';yaml.dump(yaml_data, open('$YAML_FILE', 'w'), default_flow_style=False);"
# }

get_mem_per_node() {
  #echo "$(scontrol show job $SLURM_JOBID | grep 'mem' | sed 's/.*MinMemoryNode=\(.*\),node.*/\1/g')"
  echo "$(scontrol show job $SLURM_JOBID | grep 'MinMemoryNode' | sed 's/.*MinMemoryNode=\(.*\)\s.*/\1/g')"
}

print_experiment_info() {
  if [[ "$JOB_TYPE" == "local" ]]; then
    logger_info "Experiment info:"
    logger_info "   Pipeline type: $PIPELINE_TYPE"
    logger_info "   Run: $RUN_NUM"
    logger_info "   Number of nodes: 1"
    logger_info "   Parallelism: $($YQ '.stream_processor.worker.parallelism' ${CONF_FILE})"
  else
    logger_info "Experiment info:"
    logger_info "   Slurm Job ID: $SLURM_JOBID"
    logger_info "   Pipeline type: $PIPELINE_TYPE"
    logger_info "   Run: $RUN_NUM"
    logger_info "   Number of nodes: $SLURM_NNODES"
    logger_info "   Number of CPUs per node: $SLURM_CPUS_ON_NODE"
    logger_info "   Total memory per node: $(get_mem_per_node)"
  fi
}

round_off() {
  echo $1 | awk '{print int($1+0.5)}'
}

get_timestamp() {
  echo $(date +%Y%m%d%H%M%S)
}

fetch_untar_file() {
  local FILE="$1"
  local URL="$2"
  local FW_DIR="$3"
  local CACHE_DIR="$FW_DIR/download-cache"
  if [[ -e "$CACHE_DIR/$FILE" ]]; then
    logger_info "Using cached File $FILE"
  else
    mkdir -p $CACHE_DIR
    wget -O "$CACHE_DIR/$FILE" "$URL"
  fi
  mkdir -p "$FW_DIR"
  tar -xzvf "$CACHE_DIR/$FILE" --directory "$FW_DIR"
}

kafka_topic_cmd() {
  KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:$KAFKA_CONF_DIR/tools-log4j.properties" \
    $KAFKA_HOME/bin/kafka-topics.sh "$@"
}

create_or_update_kafka_topic() {
  # Check if the required number of arguments are provided
  if [ "$#" -lt 3 ]; then
    echo "Usage: create_or_update_topics <bootstrap_server> <partition_number> <topic1> [<topic2> <topic3> ...]"
    return 1
  fi
  local bootstrap_server="$1"
  local partition_number="$2"
  shift 2 # Remove the first two arguments (bootstrap_server and partition_number)
  # Loop through each provided topic
  for topic_name in "$@"; do
    kafka_tool_wrapper kafka-topics.sh --if-exists --bootstrap-server "$bootstrap_server" --delete --topic "$topic_name"
    kafka_tool_wrapper kafka-topics.sh --if-not-exists --bootstrap-server "$bootstrap_server" --create --topic "$topic_name" --partitions "$partition_number" --replication-factor 1 >/dev/null 2>&1
    logger_info "Topic $topic_name created with $partition_number partitions."
  done
}

delete_all_kafka_topics() {
  bootstrap_server=$1
  if [[ "$#" -lt 1 ]]; then
    echo "Usage: $0 <bootstrap_server>"
    return 1
  fi
  # Get the list of topics
  topics=$($KAFKA_TOPIC_CMD --bootstrap-server "$bootstrap_server" --list)

  # Check if there are any topics
  if [ -z "$topics" ]; then
    logger_info "No topics found on the Kafka cluster."
  else
    # Loop through each topic and delete it
    for topic in $topics; do
      $KAFKA_TOPIC_CMD --bootstrap-server "$bootstrap_server" --delete --topic "$topic"
      logger_info "Deleted topic: $topic"
    done

    logger_info "All topics deleted successfully."
  fi
}

format_time() {
  minutes=$1

  # Calculate days, hours, minutes, and seconds
  days=$((minutes / 1440))
  remaining_minutes=$((minutes % 1440))
  hours=$((remaining_minutes / 60))
  remaining_minutes=$((remaining_minutes % 60))
  seconds=0

  formatted_time=$(printf "%02d-%02d:%02d:%02d" "$days" "$hours" "$remaining_minutes" "$seconds")

  echo "$formatted_time"
}

check_directory() {
  # usage is without dollar sign: check_directory mydir
  local MYDIR=${!1}
  local MYVAR=$1
  if [[ "$MYDIR" == "" ]]; then
    logger_error "The directory variable ($MYVAR) is empty. Check the experiment workflow."
    exit 1
  fi
  if [[ ! -d "$MYDIR" ]]; then
    logger_error "The directory ($MYDIR) doesn't exist. Check the experiment workflow."
    exit 3
  fi
}

check_file() {
  # usage is without dollar sign: check_file myfile
  local MYFILE=${!1}
  local MYVAR=$1
  if [[ "$MYFILE" == "" ]]; then
    logger_error "The file variable ($MYVAR) is empty. Check the experiment workflow."
    exit 1
  fi
  if [[ ! -f "$MYFILE" ]]; then
    logger_error "The file ($MYFILE) doesn't exist. Check the experiment workflow."
    exit 3
  fi
}

check_var() {
  # usage is without dollar sign: check_file myfile
  local MYVARCONTENTS=${!1}
  local MYVAR=$1
  if [[ "$MYVARCONTENTS" == "" ]]; then
    logger_error "The file variable ($MYVAR) is empty. Check the experiment workflow."
    exit 1
  fi
}

# To detect HPC
is_hpc() {
  hostname -f | grep -q 'hpc.tu-dresden' && return 0 || return 1
}

safe_remove_recursive() {
  # Ensure KAFKA_LOG_DIR is set
  if [ -z "$1" ]; then
    logger_error "Error: KAFKA_LOG_DIR is not set. Not removing."
  elif [ ! -d "$1" ]; then
    # Check if the directory exists
    logger_error "Directory $KAFKA_LOG_DIR does not exist. Not removing."
  else
    # Remove the original directory
    logger_info "Attempting to remove directory $1"
    rm -r "$1"
  fi
}

# Function to get a list of CPUs
get_cpus() {
  # get_cpus "<STARTING_INDEX_OF_CPUID>" "<INDEX of N+1 CPU>"
  # get_cpus "1" "2"
  # -> 32 34

  # Check if the required arguments are provided
  if [ $# -ne 2 ]; then
    echo "Usage: get_cpus <STARTING_INDEX_OF_CPUID> <INDEX of N+1 CPU>"
    return 1
  fi

  local START=$1
  local END=$2

  # Validate the input indices
  if [ $START -lt 0 ] || [ $END -le $START ]; then
    echo "Invalid input indices. START must be non-negative and less than END."
    return 1
  fi

  # Get the list of available CPUs
  local CPU_LIST=$(taskset -c -p $$ | cut -d: -f2 | tr -d ' ')

  # Parse the CPU list and generate a sequence of CPU IDs
  CPU_LIST=$(echo $CPU_LIST | tr ',' '\n' | while read range; do
    if [[ $range == *-* ]]; then
      seq $(echo $range | tr '-' ' ')
    else
      echo $range
    fi
  done | tr '\n' ' ')

  # Split the CPU list into an array
  read -r -a CPU_ARRAY <<<"$CPU_LIST"

  # Check if the START index is within the bounds of the array
  if [ $START -ge ${#CPU_ARRAY[@]} ]; then
    echo "START index is out of bounds."
    return 1
  fi

  if [ $END -ge ${#CPU_ARRAY[@]} ]; then
    echo "END index is out of bounds."
    return 1
  fi

  # Check if the END index is within the bounds of the array
  if [ $END -gt ${#CPU_ARRAY[@]} ]; then
    END=${#CPU_ARRAY[@]}
  fi

  # Select the subset based on given range
  FINAL_CPU="${CPU_ARRAY[@]:$START:$((END - START))}"
  FINAL_CPU=$(echo "$FINAL_CPU" | tr ' ' ',' | sed 's/,$//')

  # Print the subset of CPUs
  echo $FINAL_CPU
}
