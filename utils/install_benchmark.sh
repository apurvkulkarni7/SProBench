#!/bin/bash
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

# Check and install python
setup_virtual_env() {
  if [ "$SPB_SYSTEM" = "localmachine" ]; then
    # Setup python, if not available
    if ! $(which python); then
      echo "Python version not available."
      sudo apt update
      sudo apt install -y python3.11
    else
      PYTHON="$(which python)"
    fi
  fi

  if [ ! -f "./venv/bin/python" ]; then
    echo "Creating virtual environment"
    $PYTHON -m venv ./venv
  fi
  source ./venv/bin/activate
  pip install -r ./utils/requirements.txt
}

check_java_installed() {
  local JAVA_VERSION=$1
  local JAVA_HOME=$2
  local JAVA="$JAVA_HOME/bin/java"
  local required_version="$JAVA_VERSION"
  if ! command -v $JAVA &>/dev/null; then
    echo "Java is not installed."
    return 1
  fi
  local java_version_output
  java_version_output=$($JAVA -version 2>&1)

  if echo "$java_version_output" | grep -q "version \"$required_version"; then
    echo "Java $required_version is already installed."
    return 0
  elif echo "$java_version_output" | grep -q "version \"1.$required_version"; then
    echo "Java 1.$required_version is already installed."
    return 0
  elif echo "$java_version_output" | grep -q "version \"$required_version."; then
    echo "Java $required_version.x is already installed."
    return 0
  else
    echo "Java is installed but not version $required_version."
    echo "Installed version: "
    echo "$java_version_output"
    return 1
  fi
}

download_java() {
  local JAVA_VERSION=$1
  local JAVA_MAJOR_VERSION=$(echo $JAVA_VERSION | cut -d'.' -f1)
  local JAVA_PATH=$2
  local JAVA_LINK="https://download.java.net/java/GA/jdk${JAVA_MAJOR_VERSION}/9/GPL/openjdk-${JAVA_VERSION}_linux-x64_bin.tar.gz"
  echo "Installing OpenJDK ${JAVA_VERSION} at ${JAVA_PATH}..."
  if [ ! -f "${JAVA_PATH}/openjdk.tar.gz" ]; then
    wget -O "${JAVA_PATH}/openjdk.tar.gz" "$JAVA_LINK"
  fi
  tar -zxf "${JAVA_PATH}/openjdk.tar.gz" -C "${JAVA_PATH}/"
  mv "${JAVA_PATH}/jdk-${JAVA_VERSION}/"* "${JAVA_PATH}/"
}

setup_java() {

  # Create installation directory
  mkdir -p "$DEFAULT_PATH"

  local JAVA_VERSION=$($YQ '.frameworks.java.version' $CONF_FILE)

  case $SPB_SYSTEM in
  localmachine)
    local JAVA_PATH=$($YQ '.frameworks.java.local_setup.path' $CONF_FILE)
    if [[ $JAVA_PATH == 'default' ]]; then
      JAVA_PATH="${DEFAULT_PATH}/java"
      mkdir -p $JAVA_PATH
    fi
    JAVA_HOME="${JAVA_PATH}"
    if check_java_installed "$JAVA_VERSION" "$JAVA_HOME"; then
      echo "Skipping installation."
    else
      download_java $JAVA_VERSION $JAVA_HOME
    fi
    ;;
  slurm_interactive | slurm_batch)
    local USE_JAVA_MODULE=$($YQ '.frameworks.java.slurm_setup.use_module_system' $CONF_FILE)

    if [[ "${USE_JAVA_MODULE}" == "true" ]]; then
      echo "Loading Java module on Slurm system..."
      module load $($YQ '.frameworks.java.slurm_setup.module_name_version' $CONF_FILE)
      if ! check_java_installed "$JAVA_VERSION" "$JAVA_HOME"; then
        echo "Warning: Loaded Java module may not be version $JAVA_VERSION."
        echo "Please check if the correct Java module is available on this Slurm system."
      fi
    else
      local JAVA_PATH=$($YQ '.frameworks.java.slurm_setup.path' $CONF_FILE)
      if [[ $JAVA_PATH == 'default' ]]; then
        JAVA_PATH="${DEFAULT_PATH}/java"
        mkdir -p $JAVA_PATH
      fi
      JAVA_HOME=${JAVA_PATH}
      if check_java_installed "$JAVA_VERSION" "$JAVA_HOME"; then
        echo "Skipping installation."
      else
        download_java $JAVA_VERSION $JAVA_HOME
      fi
    fi
    ;;
  esac
  export JAVA_HOME

  # Verify Java installation
  $JAVA_HOME/bin/java -version >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Java installation/loading failed. Exiting."
    exit 1
  fi
  echo "Java setup completed."
}

check_maven_installed() {
  local MAVEN_VERSION=$1
  local MAVEN_HOME=$2
  local MAVEN="$(realpath $MAVEN_HOME)/bin/mvn"
  local required_version="$MAVEN_VERSION"
  if ! command -v $MAVEN &>/dev/null; then
    echo "Maven is not installed."
    return 1
  fi
  local maven_version_output
  maven_version_output=$($MAVEN -version 2>&1)
  if echo "$maven_version_output" | grep -q "Apache Maven $required_version"; then
    echo "Maven $required_version is already installed."
    return 0
  else
    echo "Maven is installed but not version $required_version."
    echo "Installed version: "
    echo "$maven_version_output"
    return 1
  fi
}

download_maven() {
  local MAVEN_VERSION=$1
  local MAVEN_PATH=$2
  local MAVEN_LINK="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"

  echo "Installing Maven ${MAVEN_VERSION} at ${MAVEN_PATH}..."
  if [ ! -f "${MAVEN_PATH}/maven.tar.gz" ]; then
    wget -O "${MAVEN_PATH}/maven.tar.gz" "$MAVEN_LINK"
  fi
  tar -zxf "${MAVEN_PATH}/maven.tar.gz" -C "${MAVEN_PATH}/"
  mv "${MAVEN_PATH}/apache-maven-${MAVEN_VERSION}/"* "${MAVEN_PATH}/"
}

setup_maven() {

  # Create installation directory
  mkdir -p "$DEFAULT_PATH"
  local MAVEN_VERSION=$($YQ '.frameworks.maven.version' $CONF_FILE)

  case $SPB_SYSTEM in
  localmachine)
    local MAVEN_PATH=$($YQ '.frameworks.maven.local_setup.path' $CONF_FILE)
    if [[ $MAVEN_PATH == 'default' ]]; then
      MAVEN_PATH="${DEFAULT_PATH}/maven"
      mkdir -p $MAVEN_PATH
    fi
    MAVEN_HOME="${MAVEN_PATH}"
    if check_maven_installed "$MAVEN_VERSION" "$MAVEN_HOME"; then
      echo "Skipping installation."
    else
      download_maven $MAVEN_VERSION $MAVEN_HOME
    fi
    ;;
  slurm_interactive | slurm_batch)
    local USE_MAVEN_MODULE=$($YQ '.frameworks.maven.slurm_setup.use_module_system' $CONF_FILE)

    if [[ "${USE_MAVEN_MODULE}" == "true" ]]; then
      echo "Loading Maven module on Slurm system..."
      module load $($YQ '.frameworks.maven.slurm_setup.module_name_version' $CONF_FILE)
      if ! check_maven_installed "$MAVEN_VERSION" "$MAVEN_HOME"; then
        echo "Warning: Loaded Java module may not be version $MAVEN_VERSION."
        echo "Please check if the correct Java module is available on this Slurm system."
      fi
    else
      local MAVEN_PATH=$($YQ '.frameworks.maven.slurm_setup.path' $CONF_FILE)
      if [[ $MAVEN_PATH == 'default' ]]; then
        MAVEN_PATH="${DEFAULT_PATH}/java"
        mkdir -p $MAVEN_PATH
      fi
      MAVEN_HOME=${MAVEN_PATH}
      if check_maven_installed "$MAVEN_VERSION" "$MAVEN_HOME"; then
        echo "Skipping installation."
      else
        download_maven $MAVEN_VERSION $MAVEN_HOME
      fi
    fi
    ;;
  esac

  # Verify Maven installation
  $MAVEN_HOME/bin/mvn -version >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Maven installation/loading failed. Exiting."
    exit 1
  fi
  echo "Maven setup completed."
}

setup_python() {
  # installation link: #https://www.python.org/downloads/release/python-3115/
  if command -v python &>/dev/null; then
    echo Python is already installed, skipping installation
  else
    echo "Please install python "
  fi

  # Setup virtual env
  VENV_DIR="${CURR_DIR}/venv"

  if [ ! -f "${VENV_DIR}/bin/python" ]; then
    echo "Creating virtual environment required for postprocessing"
    python3 -m venv $VENV_DIR
  else
    echo "Virtual environment found at ${VENV_DIR}"
  fi

  source "${VENV_DIR}/bin/activate"
  pip install -r $CURR_DIR/requirements.txt
  echo "Python virtual environment setup complete"
}

extract_suffix_from_url() {
  local url="$1"
  local filename="${url##*/}"
  if [[ "$filename" =~ tar.gz ]]; then
    suffix=".tar.gz"
  else
    suffix="${filename##*.}"
  fi
  printf '%s' $suffix
}

check_framework_installed() {
  local FRAMEWORK_NAME=$1
  local FRAMEWORK_VERSION=$2
  local FRAMEWORK_HOME=$3
  local FRAMEWORK_CMD=$4

  local FRAMEWORK_BIN_CMD="$(realpath ${FRAMEWORK_HOME})/bin/${FRAMEWORK_BIN_CMD}"

  local required_version="$FRAMEWORK_VERSION"
  if ! command -v $FRAMEWORK_BIN_CMD &>/dev/null; then
    echo "${FRAMEWORK_NAME} is not installed."
    return 1
  fi
  local version_output
  version_output=$($FRAMEWORK_BIN_CMD --version 2>&1)
  if echo "$version_output" | grep -q "$FRAMEWORK_VERSION"; then
    echo "${FRAMEWORK_NAME} $FRAMEWORK_VERSION is already installed."
    return 0
  else
    echo "${FRAMEWORK_NAME} is installed but not version $FRAMEWORK_VERSION."
    echo "Installed version: "
    echo "$version_output"
    return 1
  fi
}

download_frameworks() {
  local FRAMEWORK_NAME=$1
  local FRAMEWORK_VERSION=$2
  local FRAMEWORK_PATH=$3
  local FRAMEWORK_LINK=$4
  local ARCHIVE_SUFFIX=$(extract_suffix_from_url $FRAMEWORK_LINK)

  echo "Installing ${FRAMEWORK_NAME} ${FRAMEWORK_VERSION} at ${FRAMEWORK_PATH}"
  ARCHIVE_FILE="${FRAMEWORK_PATH}/${FRAMEWORK_NAME}.${ARCHIVE_SUFFIX}"

  if [[ ! -f "$ARCHIVE_FILE" ]]; then
    wget -O "${ARCHIVE_FILE}" "$FRAMEWORK_LINK"
  fi
  tar -zxf "$ARCHIVE_FILE" -C "${FRAMEWORK_PATH}"
  FRAMEWORK_TMP_DIR=$(find "${FRAMEWORK_PATH}/"* -maxdepth 1 -type d -name "${FRAMEWORK_NAME}*")
  cp -r "${FRAMEWORK_TMP_DIR}/"* "${FRAMEWORK_PATH}/"
}

setup_frameworks() {

  local FRAMEWORK_NAME=$1
  FRAMEWORK_NAME=${FRAMEWORK_NAME,,}

  # Create installation directory
  mkdir -p "$DEFAULT_PATH"
  local FRAMEWORK_VERSION=$($YQ '.frameworks.'${FRAMEWORK_NAME}'.version' $CONF_FILE)

  if [[ "${FRAMEWORK_NAME}" == 'kafka' ]]; then
    DOWNLOAD_LINK="https://archive.apache.org/dist/kafka/${FRAMEWORK_VERSION}/kafka_2.13-${FRAMEWORK_VERSION}.tgz"
    FRAMEWORK_BIN_CMD="kafka-topics.sh"
  elif [[ $FRAMEWORK_NAME == 'flink' ]]; then
    DOWNLOAD_LINK="https://downloads.apache.org/flink/flink-${FRAMEWORK_VERSION}/flink-${FRAMEWORK_VERSION}-bin-scala_2.12.tgz"
    FRAMEWORK_BIN_CMD="flink"
  elif [[ $FRAMEWORK_NAME == 'spark' ]]; then
    DOWNLOAD_LINK="https://archive.apache.org/dist/spark/spark-${FRAMEWORK_VERSION}/spark-${FRAMEWORK_VERSION}-bin-hadoop3.tgz"
    FRAMEWORK_BIN_CMD="spark-submit"
  fi

  case $SPB_SYSTEM in
  localmachine)
    local FRAMEWORK_PATH=$($YQ '.frameworks.'${FRAMEWORK_NAME}'.local_setup.path' $CONF_FILE)

    if [[ "${FRAMEWORK_PATH}" == 'default' ]]; then
      FRAMEWORK_PATH="${DEFAULT_PATH}/${FRAMEWORK_NAME}"
      mkdir -p "${FRAMEWORK_PATH}"
    fi
    FRAMEWORK_HOME="${FRAMEWORK_PATH}"

    if check_framework_installed "$FRAMEWORK_NAME" "$FRAMEWORK_VERSION" "$FRAMEWORK_HOME" "$FRAMEWORK_BIN_CMD"; then
      echo "Skipping installation."
    else
      download_frameworks "$FRAMEWORK_NAME" "$FRAMEWORK_VERSION" "$FRAMEWORK_PATH" "$DOWNLOAD_LINK"
    fi
    ;;
  slurm_interactive | slurm_batch)
    local USE_MODULE=$($YQ '.frameworks.'${FRAMEWORK_NAME}'.slurm_setup.use_module_system' $CONF_FILE)

    if [[ "${USE_MODULE}" == "true" ]]; then
      echo "Loading ${FRAMEWORK_NAME} module on Slurm system..."
      module load $($YQ '.frameworks.'${FRAMEWORK_NAME}'.slurm_setup.module_name_version' $CONF_FILE)
      if ! check_framework_installed "$FRAMEWORK_NAME" "$FRAMEWORK_VERSION" "$FRAMEWORK_HOME" "$FRAMEWORK_BIN_CMD"; then
        echo "Warning: Loaded ${FRAMEWORK_NAME} module may not be version $FRAMEWORK_VERSION."
        echo "Please check if the correct ${FRAMEWORK_NAME} module is available on this Slurm system."
      fi
    else
      local FRAMEWORK_PATH=$($YQ '.frameworks.maven.slurm_setup.path' $CONF_FILE)
      if [[ $FRAMEWORK_PATH == 'default' ]]; then
        FRAMEWORK_PATH="${DEFAULT_PATH}/java"
        mkdir -p $FRAMEWORK_PATH
      fi
      FRAMEWORK_HOME=${FRAMEWORK_PATH}
      if check_framework_installed "$FRAMEWORK_NAME" "$FRAMEWORK_VERSION" "$FRAMEWORK_HOME" "$FRAMEWORK_BIN_CMD"; then
        echo "Skipping installation."
      else
        download_frameworks "$FRAMEWORK_NAME" "$FRAMEWORK_VERSION" "$FRAMEWORK_PATH" "$DOWNLOAD_LINK"
      fi
    fi
    ;;
  esac

  eval "${FRAMEWORK_NAME^^}_HOME"=$FRAMEWORK_HOME

  local FRAMEWORK_BIN_CMD="$(realpath ${FRAMEWORK_HOME})/bin/${FRAMEWORK_BIN_CMD}"
  command -v "$FRAMEWORK_BIN_CMD" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "${FRAMEWORK_NAME^^} installation/loading failed. Exiting."
    exit 1
  fi
  echo "${FRAMEWORK_NAME} setup completed."
}

################################################################################

SPB_SYSTEM=$1
CONF_FILE=$2

CURR_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# Parse command-line arguments
SETUP_YAML_PARSER=1

# Main interactive prompt
echo "┌──────────────────────────────────────────────────────────────────────┐"
echo "│                     Benchmark Installation Setup                     │"
echo "└──────────────────────────────────────────────────────────────────────┘"

declare -A FRAMEWORKS_SETUP=(
  [0]="All SETUP_ALL"
  [1]="Java SETUP_JAVA"
  [2]="Python SETUP_PYTHON"
  [3]="Apache_Flink SETUP_FLINK"
  [4]="Apache_Spark SETUP_SPARK"
  [5]="Apache_Kafka SETUP_KAFKA"
  [6]="Apache_Maven SETUP_MAVEN"
  [7]="Python_Virtual_Env SETUP_VENV"

)

# Initialize all setup flags to 0
for key in "${!FRAMEWORKS_SETUP[@]}"; do
  value=${FRAMEWORKS_SETUP[$key]}
  setup_var=$(echo "$value" | cut -d' ' -f2)
  declare "$setup_var=0"
done

echo
echo "───────── Framework Selection ──────────────────────────────────────────"
echo
for setup_idx in $(printf '%s\n' "${!FRAMEWORKS_SETUP[@]}" | sort); do
  value=${FRAMEWORKS_SETUP[$setup_idx]}
  setup_name=$(echo "$value" | cut -d' ' -f1)
  echo " $setup_idx $setup_name"
done
echo
echo "Which frameworks to install ? For multiple, space seperated numerical values."
read -p "" INSTALL_CHOICE

# Selection check
SETUP_LENGTH=${#FRAMEWORKS_SETUP[@]}
((SETUP_LENGTH--))
for install_choice_i in $INSTALL_CHOICE; do
  # Check if choice is within bounds
  if [[ $install_choice_i -lt 0 ]] || [[ $install_choice_i -gt $SETUP_LENGTH ]]; then
    echo "Selection $install_choice_i is out of bounds"
    echo "Please choose at correct index for the framework."
    exit 1
  fi
done
# Check if choice is empty
if [ -z "$INSTALL_CHOICE" ]; then
  echo "No components selected. Please choose at least one framework."
  exit 1
fi

# Assing values
if [[ "${INSTALL_CHOICE}" == "0" ]]; then
  declare "SETUP_ALL=1"
else
  declare "SETUP_ALL=0"
  for install_choice_i in $INSTALL_CHOICE; do
    value=${FRAMEWORKS_SETUP[$install_choice_i]}
    setup_var=$(echo "$value" | cut -d' ' -f2)
    # Set values to 1 for selected framework
    declare "$setup_var=1"
  done
fi

# Display summary
echo
echo "┌──────────────────────────────────────────────────────────────────────┐"
echo "│                          Configuration                               │"
echo "└──────────────────────────────────────────────────────────────────────┘"
echo " System Type:         $SPB_SYSTEM"
echo "────────────────────────────────────────────────────────────────────────"

echo "The following frameworks will be installed:"
for key in "${!FRAMEWORKS_SETUP[@]}"; do
  value=${FRAMEWORKS_SETUP[$key]}
  setup_name=$(echo "$value" | cut -d' ' -f1)
  setup_var=$(echo "$value" | cut -d' ' -f2)
  setup_var_val=${!setup_var}
  if [[ $setup_var_val -eq 1 ]]; then
    echo "- $setup_name"
  fi
done
echo
echo "Note: The benchmark uses a yaml parser from: "
echo "https://github.com/mikefarah/yq"
echo "This executable will be downloaded automatically in the <Benchmark>/utils"
echo "────────────────────────────────────────────────────────────────────────"
echo

# Confirmation prompt
read -p "Proceed with installation? [Y/n] " confirm
[[ $confirm =~ ^[Yy]$ ]] || (echo "Invalid input" && exit 1)

# This gives user some time to cancel the installation process.
LAUNCH_TIME_SEC=5
echo "Starting installation process in ${LAUNCH_TIME_SEC} sec"
while [ $LAUNCH_TIME_SEC -gt 0 ]; do
  echo -ne "Time remaining: $LAUNCH_TIME_SEC seconds\r"
  sleep 1
  ((LAUNCH_TIME_SEC--))
done

# Setup yaml parser should be downloaded in the utils file
if [[ $SETUP_YAML_PARSER -eq 1 ]]; then
  echo "Setting up yaml file"
  if [ ! -f "${CURR_DIR}/yaml_parser" ]; then
    wget -qO "${CURR_DIR}/yaml_parser" https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  fi
  chmod +x "${CURR_DIR}/yaml_parser"
fi
YQ="${CURR_DIR}/yaml_parser eval"

# Get paths from the configuration file
DEFAULT_PATH="$(realpath ${CURR_DIR}/../frameworks)"
case $SPB_SYSTEM in
localmachine)
  if [ $SETUP_JAVA -eq 1 ] || [ $SETUP_ALL -eq 1 ]; then setup_java; fi
  if [ $SETUP_MAVEN -eq 1 ] || [ $SETUP_ALL -eq 1 ]; then setup_maven; fi
  if [ $SETUP_VENV -eq 1 ] || [ $SETUP_ALL -eq 1 ]; then setup_python; fi
  if [ $SETUP_KAFKA -eq 1 ] || [ $SETUP_ALL -eq 1 ]; then setup_frameworks "kafka"; fi
  if [ $SETUP_FLINK -eq 1 ] || [ $SETUP_ALL -eq 1 ]; then setup_frameworks "flink"; fi
  if [ $SETUP_SPARK -eq 1 ] || [ $SETUP_ALL -eq 1 ]; then setup_frameworks "spark"; fi
  ;;
slurm_interactive | slurm_batch)
  # Check if path module is empty or has some value as none, if it has, then insall
  # the frameworks in default/provided location
  echo ""
  ;;
esac

echo "Setup complete."

exit 0
