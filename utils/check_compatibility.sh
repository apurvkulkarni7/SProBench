#!/bin/bash
set -e 

BENCHMARK_DIR="$(dirname $(dirname $(realpath $0)))"
source $BENCHMARK_DIR/utils/init.sh

# Initialize the framework
source $BENCHMARK_DIR/utils/setup_framework.sh CHECK $1

# Function to check module version
check_module_version() {
    local module_name=$1
    local expected_version=$2
    
}

check_version() {
    local cmd=$1
    local expected_version=$2
    local version_cmd=$3
    local version_regex=$4
    local framework_name=$5
    
    if is_hpc; then
        local module_name=$cmd
        
        module load "$module_name/$expected_version" &> /dev/null
        if [[ $? -eq 0 ]]; then
            echo "Module $module_name/$expected_version is available."
        else
            echo "Module $module_name/$expected_version is not available."
        fi
    else
        if which "$cmd" &> /dev/null; then  
            output_version_cmd="$(eval $version_cmd)"
            actual_version=$(echo $output_version_cmd | grep -oP "$version_regex")
            if [[ $actual_version == "$expected_version" ]]; then
                echo -e "[x] $framework_name\t: installed with expected version $expected_version"
            else
                echo -e "[ ] $framework_name\t: installed but with version $actual_version instead of $expected_version"
            fi
        else
            echo "[x] $framework_name\t\t: $cmd is not installed. Check if $framework_name is insalled."
        fi
    fi
}

if is_hpc; then
    # Check modules
    check_version "Java" "11.0.20"
    check_version "Maven" "3.9.6"
    check_version "Flink" "1.17.1"
    check_version "Spark" "3.5.0"
    check_version "Kafka" "3.6.1"
else
    # Check Java
    check_version "$JAVA" "11.0.23" "$JAVA -version 2>&1" '(?<=openjdk version ")\d+\.\d+\.\d+' 'Java\t'

    # Check Maven
    check_version "$MVN" "3.9.6" "$MVN -version" '(?<=Apache Maven )\d+\.\d+\.\d+' 'Apache Maven'

    # Check Kafka
    check_version "$KAFKA_HOME/bin/kafka-topics.sh" "3.6.1" "$KAFKA_HOME/bin/kafka-topics.sh --version 2>&1" '\d+\.\d+\.\d+' 'Apacke Kafka'

    # Check Flink
    check_version "$FLINK_HOME/bin/flink" "1.18.1" "$FLINK_HOME/bin/flink --version" '\d+\.\d+\.\d+' 'Apache Flink'

    # Check Spark
    check_version "$SPARK_HOME/bin/spark-submit" "3.5.1" "$SPARK_HOME/bin/spark-submit --version 2>&1" '(?<=_\\\sversion\s)\d+\.\d+\.\d+' 'Apache Spark'
fi