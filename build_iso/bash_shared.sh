#!/bin/bash

DEFAULT_BUILDER_LOG="/tmp/build/build_main.log"
EXPECTED_DIRS=("/usr" "/Users/spyroot" "/usr/local")
ROOT_BUILD="/Users/spyroot/test"
SKIP_CLEANUP="yes"

AVX_VERSION=4.5.3
MLNX_VER=5.4-1.0.3.0

export LANG=en_US.UTF-8
export LC_ALL=$LANG

DPDK_URL_LOCATIONS=(
  "http://fast.dpdk.org/rel/dpdk-21.11.tar.xz" "https://drive.google.com/u/0/uc?id=1EllCI6gkZ3O70CXAXW9F4QCFD6IrGgZx&export=download&confirm=1e-b")


LIB_NL_LOCATION=(
  "https://www.infradead.org/~tgr/libnl/files/libnl-3.2.25.tar.gz" "https://www.infradead.org/~tgr/libnl/files/libnl-3.2.25.tar.gz"
)

IAVF_LOCATION=(
  "https://downloadmirror.intel.com/738727/iavf-$AVX_VERSION.tar.gz" "https://downloadmirror.intel.com/738727/iavf-$AVX_VERSION.tar.gz"
)

MELLANOX_LOCATION=(
  "http://www.mellanox.com/downloads/ofed/MLNX_OFED-$MLNX_VER/MLNX_OFED_SRC-debian-$MLNX_VER.tgz"
  "http://www.mellanox.com/downloads/ofed/MLNX_OFED-$MLNX_VER/MLNX_OFED_SRC-debian-$MLNX_VER.tgz"
)

trim() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  echo "$var"
}

# check if file exists or not
function file_exists {
  local -r a_file="$1"
  [[ -f "$a_file" ]]
}

# log message to console and file.
function log_console_and_file() {
  local log_dir
  local default_log=$DEFAULT_BUILDER_LOG
  printf "%b %s %b\n" "${GREEN}" "$@" "${NC}"

  log_dir=$(extrac_dir $default_log)
  if [ ! -d log_dir ]; then
    mkdir -p "$log_dir"
  fi

  if file_exists "$default_log"; then
    echo "$@" >>"$default_log"
  else
    echo "$@" >"$default_log"
  fi
}

# /mnt/cdrom/direct/dpdk-21.11.3.tar.xz
# Function extract version from
# filename, url , or full path
# "dpdk-21.11.3.tar.xz" -> 21.11.3
# "/mnt/cdrom/direct/dpdk-21.11.3.tar.xz" -> 21.11.3
# http://fast.dpdk.org/rel/dpdk-21.11.tar.xz" -> 21.11
function extrac_version() {
  local file_path=$1
  local pref=$2
  local suffix=$3
  local version
  version=""

  if [ -z "$file_path" ] || [ -z "$pref" ] || [ -z "$suffix" ]; then
    version=""
  else
    file_path=$(trim "$file_path")
    local file_name
    file_name=$(basename "$file_path")
    version=${file_name/#$pref/}
    version=${version/%$suffix/}
  fi

  echo "$version"
}

# Extract directory
function extrac_dir() {
  local dir_path=$1
  local dir_name
  dir_name=""

  if [ -z "$dir_path" ]; then
    dir_name=""
  else
    local dir_name
    dir_path=$(trim "$dir_path")
    dir_name=$(dirname "$dir_path")
  fi

  echo "$dir_name"
}

# extrac filename
function extrac_filename() {
  local file_path=$1
  local file_name
  file_name=""

  if [ -z "$file_path" ]; then
    file_name=""
  else
    local file_name
    file_path=$(trim "$file_path")
    file_name=$(basename "$file_path")
  fi

  echo "$file_name"
}

# Function search a file in array of dirs
# first argument is suffix for a file
# second argument is prefix.
# suffix and prefix used to extrac version.
# third argument a pattern dpdk, iavf etc.
# last argument what we search, for logging purpose.
function search_file() {
  local search_pattern=$1
  local target_name=$2
  local suffix=$3
  local  __resul_search_var=$4
  local found_file=""
  local found_dir=""

  # first check all expected dirs
  for expected_dir in "${EXPECTED_DIRS[@]}"; do
    log_console_and_file "Searching $target_name in $expected_dir"
    found_file=$(ls "$expected_dir" 2>/dev/null | grep "$search_pattern*")
    if [ -n "$found_file" ]; then
      log_console_and_file "Found $target_name in $expected_dir"
      found_dir=expected_dir
      break
    fi
  done

  # mount cdrom and check
  if [ -z "$found_file" ]; then
    log_console_and_file "Mounting cdrom and searching $target_name"
    mount /dev/cdrom 2>/dev/null
    found_file=$(ls /mnt/cdrom/direct 2>/dev/null | grep "$search_pattern*")
  else
    log_console_and_file "Found local copy $direct_file"
  fi

  # mount cdrom and check
  if [ -z "$found_file" ]; then
    local search_regex
    search_regex=".*$search_pattern.*.$suffix"
    log_console_and_file "File not found, doing deep search pattern $search_regex"
    found_file="$(cd / || exit; find / -type f -regex "$search_regex" -maxdepth 10 2>/dev/null | head -n 1)"
    log_console_and_file "Result of deep search $found_file"
  fi

  if file_exists "$found_file"; then
    log_console_and_file "Deep search found a file $found_file"
  fi

  if [[ "$__resul_search_var" ]]; then
    eval "$__resul_search_var"="'$found_file'"
  else
    echo "$found_file"
  fi
}


# Function takes target dir where to store a file
# and list of location mirror for a given file.
function fetch_file() {
  local target_dir=$1
  local  __result_fetch_var=$2
  shift 2
  local urls=("$@")
  local remote_file_name
  local full_path

  if [ ! -d target_dir ]; then
    mkdir -p "$target_dir"
  fi

  log_console_and_file "File will be saved in $target_dir"

  for url in "${urls[@]}"; do
    remote_file_name=$(extrac_filename "$url")
    log_console_and_file "Fetching file $remote_file_name from $url"
    full_path=$target_dir"/"$remote_file_name
    wget --quiet -nc "$url" -O "$remote_file_name" || rm -f "$remote_file_name"
    if file_exists "$remote_file_name"; then
      log_console_and_file "Downloaded file to $remote_file_name"
      break
    else
      log_console_and_file "Failed to fetch $remote_file_name from $url"
    fi
  done

  if file_exists "$remote_file_name"; then
    log_console_and_file "Copy file to $remote_file_name to $full_path"
    cp "$remote_file_name" "$full_path"
  fi

  if [[ "$__result_fetch_var" ]]; then
    eval "$__result_fetch_var"="'$full_path'"
  else
    echo "$full_path"
  fi
}

#unpack_all_files
function unpack_all_files() {
  local search_criterion=$1
  local file_name=$2
  local suffix=$3
  local  __result_loc_var=$4
  shift 4
  local mirrors=("$@")
  local build_location=$ROOT_BUILD/$file_name
  local search_result
  search_file "$search_criterion" "$file_name" "$suffix" search_result
  if file_exists "$search_result"; then
    log_console_and_file "Found existing file $search_result"
    mkdir -p "$build_location"
    tar -xf "$search_result" --directory "$build_location" --strip-components=1
  else
    local download_result=""
    log_console_and_file "File not found need downloading $file_name"
    fetch_file $ROOT_BUILD download_result "${mirrors[@]}"
    if file_exists "$download_result"; then
      log_console_and_file "File successfully downloaded $file_name location $download_result"
      mkdir -p "$build_location"
      tar -xf "$download_result" --directory "$build_location" --strip-components=1
    fi
  fi

  if [[ "$__result_loc_var" ]]; then
    eval "$__result_loc_var"="'$build_location'"
  else
    echo "$build_location"
  fi
}

function clean_up() {
  if [ -z "$SKIP_CLEANUP" ] || [ $SKIP_CLEANUP == "yes" ]; then
    log_console_and_file "Skipping clean up"
    rm -rf dpdk*
    rm -rf iavf-*
    rm -rf libnl-*.tgz
    rm -rf MLNX_OFED_SRC-*.tgz
    rm -rf "${ROOT_BUILD:?}/"*
  fi
}

function main() {

  # all location updated
  local dpdk_build_location=""
  local iavf_build_location=""
  local libnl_build_location=""
  local mellanox_build_location=""

  clean_up

  unpack_all_files "dpdk" "dpdk-21.11" "tar.xz" dpdk_build_location "${DPDK_URL_LOCATIONS[@]}"
  unpack_all_files "iavf-$AVX_VERSION" "iavf-$AVX_VERSION" "tar.gz" iavf_build_location "${IAVF_LOCATION[@]}"
#  unpack_all_files "libnl-3.2.25" "libnl-3.2.25" "tar.gz" libnl_build_location "${LIB_NL_LOCATION[@]}"
#  unpack_all_files "MLNX_OFED_SRC" "MLNX_OFED_SRC-debian-$MLNX_VER" "tgz" mellanox_build_location "${MELLANOX_LOCATION[@]}"
#
  echo "DPDK Build location $dpdk_build_location"
  echo "IAVF Build location $iavf_build_location"
#  echo "LIBNL Build location $libnl_build_location"
#  echo "Mellanox Build location $mellanox_build_location"
}

main
