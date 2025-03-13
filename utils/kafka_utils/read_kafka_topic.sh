#!/bin/bash
# Example:
#   ./read_kafka_topic.sh n1486 eventsOut my/Kafka/config/dir/kafka
set -e

kafka_node=$1
topic=${2:-"eventsIn"}
template=$3

curr_dir=$(dirname $(realpath $0))
source "${curr_dir}/../utils.sh"

TMP_DIR=./tmp/kafka_tmp
mkdir -p $TMP_DIR

TMP="$(realpath $(mktemp -p ${TMP_DIR}))"

if is_hpc; then
  cat << EOF > $TMP
#!/bin/bash
module load release/24.04 GCC/13.2.0 Kafka/3.6.1-scala-2.13
# . framework-configure.sh -f kafka -t $template -d ${TMP_DIR}
. framework-configure.sh -f kafka -d ${TMP_DIR}
kafka-console-consumer.sh --from-beginning --topic $topic --bootstrap-server $kafka_node:9092
EOF
  chmod +x "$TMP"
  srun --nodes=1 --cpus-per-task=1 --mem=300M --time=02:00:00 bash -c "$TMP"
  rm -r "${TMP}"
else
  $KAFKA_HOME/bin/kafka-console-consumer.sh --from-beginning --topic $topic --bootstrap-server $kafka_node:9092
fi