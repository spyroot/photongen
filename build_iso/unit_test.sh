#!/bin/bash

source bash_shared.sh

path_file="dpdk-21.11.3.tar.xz"
path_path="/mnt/cdrom/direct/dpdk-21.11.3.tar.xz"
path_url="http://fast.dpdk.org/rel/dpdk-21.11.tar.xz"
relative_path="../direct/dpdk-21.11.3.tar.xz"

function test_version_extract() {
  empty_path=""
  p="dpdk-"
  s=".tar.xz"
  ver=$(extrac_version $path_file $p $s)
  echo "from file:$ver"

  ver_b=$(extrac_version $path_path $p $s)
  echo "from path:$ver_b"

  # from url
  ver_d=$(extrac_version "$path_url" $p $s)
  echo "from url:$ver_d"

  from_relative_path=$(extrac_version "$relative_path" $p $s)
  echo "from_relative_path:$from_relative_path"

  # nil string
  nil=$(extrac_version "$path_ur2l" $p $s)
  echo "nil string :$nil"

  # nil_prefix
  nil_prefix=$(extrac_version "$path_file" "" "")
  echo "nil_prefix:$nil_prefix"

  # nil_suffix
  nil_suffix=$(extrac_version "$path_file" $p "")
  echo "nil_suffix:$nil_suffix"

  # both_nil
  both_nil=$(extrac_version "$path_file" "" "")
  echo "both_nil:$both_nil"
}

function test_version_file_name() {
  #test_version_extract
  f=$(extrac_filename $path_file)
  echo $f
  f1=$(extrac_filename $path_path)
  echo $f1
  f3=$(extrac_filename $path_url)
  echo $f3
  f4=$(extrac_filename $relative_path)
  echo $f4
}

function test_version_dir() {
  #test_version_extract
  d=$(extrac_dir $path_file)
  echo "file $d"
  d1=$(extrac_dir $path_path)
  echo "exact $d1"
  d3=$(extrac_dir $path_url)
  echo "url $d3"
  d4=$(extrac_dir $relative_path)
  echo "relative $d4"
}

EXPECTED_DIRS=("/usr" "/Users" "/usr/local")
