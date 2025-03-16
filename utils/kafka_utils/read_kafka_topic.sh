#!/bin/bash
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR



# Define usage
usage() {
  echo "Usage: $0 [hpc_node|localmachine] [TOPIC]"
  echo "  hpc_node|localmachine : Environment type"
  echo "  TOPIC                 : Kafka TOPIC name (default: eventsIn)"
}

# Check arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
      usage
else
  # Define variables
  CURR_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
  SPB_SYSTEM=$1
  TOPIC=${2:-"eventsIn"}

  KAFKA_NODE="localhost"
  if [[ ! "$SPB_SYSTEM" == "localmachine" ]]; then
    KAFKA_NODE=$1
  fi

  TOPIC=${2:-"eventsIn"}

  if [[ "$SPB_SYSTEM" == "localmachine" ]]; then

    ./frameworks/kafka/bin/kafka-console-consumer.sh --from-beginning --topic $TOPIC --bootstrap-server $KAFKA_NODE:9092

  elif [[ "$SPB_SYSTEM" =~ slurm_* ]]; then
    source "${CURR_DIR}/../utils.sh"
    TMP_DIR=./tmp/kafka_tmp
    mkdir -p $TMP_DIR

    TMP_FILE="$(realpath $(mktemp -p ${TMP_DIR}))"

    if is_hpc; then
      cat << EOF > $TMP_FILE
#!/bin/bash
module load release/24.04 GCC/13.2.0 Kafka/3.6.1-scala-2.13
source framework-configure.sh -f kafka -d ${TMP_DIR}
kafka-console-consumer.sh --from-beginning --TOPIC $TOPIC --bootstrap-server $KAFKA_NODE:9092
EOF
      chmod +x "$TMP_FILE"
      srun --nodes=1 --cpus-per-task=1 --mem=100M --time=00:10:00 bash -c "$TMP_FILE"
      rm -r "${TMP_FILE}"
    else
      $KAFKA_HOME/bin/kafka-console-consumer.sh --from-beginning --TOPIC $TOPIC --bootstrap-server $KAFKA_NODE:9092
    fi
  fi
fi