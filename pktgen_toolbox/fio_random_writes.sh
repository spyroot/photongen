#!/bin/bash
# Basic script to perform random write IOPS test using FIO
# This script uses FIO to measure the IOPS (Input/Output Operations Per Second)
# for random write operations, providing insights into the performance of the
# storage system under test. It allows for customization through environment
# variables to suit various testing needs.
#
# spyroot@gmail.com
# Author Mustafa Bayramov
#
# Description:
#   This script configures FIO to conduct a random write IOPS test, which is
#   essential for understanding how storage systems perform under random write
#   workloads. The test is highly configurable, allowing the user to specify
#   parameters such as buffer size, test duration, and I/O characteristics.
#
# Environment Variables:
#   TEST_DIR - The directory where the FIO test file will be written. This
#              variable allows the user to specify a custom directory for
#              test files.
#              Default is "/tmp" if not specified.
#              Example: export TEST_DIR="/mnt/test_directory"
#
#   SIZE - The total size of the test file(s) for each job. This parameter
#          influences how much data FIO will write to during the test.
#          Default is "10G" if not specified, representing a 10 GB file size.
#          Example: export SIZE="20G"
#
#   RUNTIME - The duration for which the test should run. This allows for
#             time-based testing, overriding the SIZE parameter if both are
#             specified.
#             Default is "60s" (60 seconds) if not specified.
#             Example: export RUNTIME="120s"
#
#   RAMP_TIME - The warm-up time before the actual measurements start. Useful
#               for allowing the system to reach a steady state.
#               Default is "2s" (2 seconds) if not specified.
#               Example: export RAMP_TIME="5s"
#
#   DIRECT - If set to "1", FIO will use direct I/O for the test, bypassing
#            the cache. This is useful for measuring the performance of the
#            storage media directly.
#            Default is "1" if not specified.
#            Example: export DIRECT="0" to use buffered I/O instead
#
#   BS - The block size for I/O operations. This parameter affects the size
#        of each write operation performed during the test.
#        Default is "4K" (4 kilobytes) if not specified.
#        Example: export BS="8K"
#
#   IODEPTH - The depth of the I/O queue. A higher value can increase
#             concurrency and potential IOPS, depending on the storage system's
#             capabilities.
#             Default is "256" if not specified.
#             Example: export IODEPTH="128"
#
# Usage:
#   To run the test with custom settings, export the desired environment
#   variables before executing this script. For example:
#
#   export TEST_DIR="/mnt/test_directory"
#   export SIZE="20G"
#   export RUNTIME="120s"
#   ./this_script_name.sh
#
#   Replace "this_script_name.sh" with the actual name of this script.
#
# Output:
#   The script outputs the test results in JSON format for easy parsing and
#   analysis. It provides detailed metrics on IOPS, throughput, and latency.
#
# Note: This script is designed for use on systems with the FIO tool installed.
#       It is suited for storage performance analysis and benchmarking.

export BENCH_DIR="${TEST_DIR:-/tmp}"

fio --name=write_iops \
--directory="${TEST_DIR}" \
--size="${SIZE:-10G}" \
--time_based \
--runtime="${RUNTIME:-60s}" \
--ramp_time="${RAMP_TIME:-2s}" \
--ioengine=libaio \
--direct="${DIRECT:-1}" \
--verify="${VERIFY:-0}" \
--bs="${BS:-4K}" \
--iodepth="${IODEPTH:-256}" \
--rw=randwrite \
--group_reporting=1  \
--iodepth_batch_submit="${IODEPTH_BATCH_SUBMIT:-256}"  \
--iodepth_batch_complete_max="${IODEPTH_BATCH_COMPLETE_MAX:-256}" \
--output-format json
