#!/bin/bash
set -e

# load_modules(){
#   modules=$@
#   for module_i in $modules; do
#     if ! module is-loaded $module_i; then
#       module load $module_i > /dev/null 2>&1
#     fi
#   done
# }

# if ! hostname -f | grep -q 'hpc.tu-dresden'; then
#   echo "Running on local machine"
# else
#   echo "Running on hpc machine"
#   echo "Loading modules required initially"
#   module purge > /dev/null 2>&1
#   load_modules "release/24.04" "GCCcore/13.2.0" "Python/3.11.5" "PyYAML/6.0.1"
# fi

case $SPB_SYSTEM in
  slurm_*)
  echo "Running on hpc machine"
  echo "Loading modules required initially"
  module purge > /dev/null 2>&1

  modules="release/24.04 GCCcore/13.2.0 Python/3.11.5 PyYAML/6.0.1"
  for module_i in $modules; do
    if ! module is-loaded $module_i; then
      module load $module_i > /dev/null 2>&1
    fi
  done
  ;;
esac


if [[ "$1" == "--ignore-benchmark-dir" ]]; then
  source "$(dirname ${BASH_SOURCE[0]})/utils.sh"
else
  if [[ "$BENCHMARK_DIR" == "" ]]; then 
    echo "Benchmark main directory not initialized/provided."
    exit 1
  fi
  source "$BENCHMARK_DIR"/utils/utils.sh
fi

