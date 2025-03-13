# Framework setup
# Default values
#export GIT=${GIT:-git}
#export MAKE=${MAKE:-make}
set -e

FRAMEWORK=$1
CONF_FILE_RUN=$2

if is_hpc; then

  module purge > /dev/null 2>&1 

  #module use /data/horse/ws/apku868a-frameworks/rapids/modules/all/Compiler/GCC/13.2.0/
  #module use /data/horse/ws/apku868a-frameworks/rapids/modules/all/Core
  
  load_modules "release/24.04"  "GCC/13.2.0" ""
  load_modules "Java/11.0.20" "Maven/3.9.6" "Kafka"

  export JAVA=$JAVA_HOME/bin/java
  export MVN=$(which mvn)
  
  if [[ "$FRAMEWORK" == "FLINK" ]] || [[ "$FRAMEWORK" == "CHECK" ]]; then
    load_modules "Flink"
    export FLINK_HOME=$FLINK_ROOT_DIR
  fi  


else

  export MVN=$(yaml $CONF_FILE_RUN '["local_setup"]["frameworks"]["maven_home"]')/bin/mvn
  export JAVA=${JAVA:-$JAVA_HOME/bin/java}
  export KAFKA_HOME="$(yaml $CONF_FILE_RUN '["local_setup"]["frameworks"]["kafka_home"]')"
  if [[ "$FRAMEWORK" == "FLINK" ]] || [[ "$FRAMEWORK" == "CHECK" ]]; then
    export FLINK_HOME="$(yaml $CONF_FILE_RUN '["local_setup"]["frameworks"]["flink_home"]')"
  fi
  if [[ "$FRAMEWORK" == "SPARK" ]] || [[ "$FRAMEWORK" == "CHECK" ]]; then
    export SPARK_HOME="$(yaml $CONF_FILE_RUN '["local_setup"]["frameworks"]["spark_home"]')"
  fi
  
fi

# echo here
# check_file JAVA
# check_file MVN
# check_directory KAFKA_HOME
# check_directory FLINK_HOME
