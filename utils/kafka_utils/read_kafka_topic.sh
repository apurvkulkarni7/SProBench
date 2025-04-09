#!/bin/bash
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

# Define usage
usage() {
  echo "Usage: $0 [TOPIC] [hpc_node|localhost]"
  echo "  TOPIC                 : Kafka TOPIC name (default: eventsIn)"
  echo "  hpc_node|localhost : Environment type"
}

# Check arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
      usage
else
  # Define variables
  CURR_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
  KAFKA_NODE=${2:-"localhost"}
  TOPIC=${1:-"eventsIn"}
  
  if [[ "$KAFKA_NODE" == "localhost" ]] || [[ "$KAFKA_NODE" == $(hostname) ]]; then
    SPB_SYSTEM='localmachine'
  fi

  TOPIC=${1:-"eventsIn"}

   
  if [[ "$SPB_SYSTEM" == "localmachine" ]]; then
    "${CURR_DIR}/../../frameworks/kafka/bin/kafka-console-consumer.sh" --from-beginning --topic "$TOPIC" --bootstrap-server "${KAFKA_NODE}:9092"
  else
    source "${CURR_DIR}/../utils.sh"
    TMP_DIR=./tmp/kafka_tmp
    mkdir -p $TMP_DIR

    TMP_FILE="$(realpath $(mktemp -p ${TMP_DIR}))"

    if is_hpc; then
      cat << EOF > $TMP_FILE
#!/bin/bash
module load release/24.04 GCC/13.2.0 Kafka/3.6.1-scala-2.13
source framework-configure.sh -f kafka -d ${TMP_DIR}
kafka-console-consumer.sh --from-beginning --topic $TOPIC --bootstrap-server $KAFKA_NODE:9092
EOF
      chmod +x "$TMP_FILE"
      srun --nodes=1 --cpus-per-task=1 --mem=300M --time=00:30:00 bash -c "$TMP_FILE"
      rm -r "${TMP_FILE}"
    else
      $KAFKA_HOME/bin/kafka-console-consumer.sh --from-beginning --TOPIC $TOPIC --bootstrap-server $KAFKA_NODE:9092
    fi
  fi
fi