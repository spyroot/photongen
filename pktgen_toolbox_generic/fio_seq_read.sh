#!/bin/bash
#!/bin/bash
# Basic script to perform sequential read tests using FIO
# This script leverages FIO to measure the sequential read performance
# of a storage device, allowing customization through environment variables.
#
# spyroot@gmail.com
# Author Mustafa Bayramov
#
# Description:
#   This script executes an FIO job that performs sequential read operations to evaluate
#   the read throughput of the storage system under test. It is configurable via
#   environment variables, making it adaptable for different testing scenarios.
#
# Environment Variables:
#   BENCH_DIR - The directory where the FIO test file will be written.
#               Default is "/tmp" if not specified.
#               Example: export BENCH_DIR="/mnt/test_directory"
#
#   NUMJOBS - The number of parallel jobs FIO will run. Increasing this number
#             simulates higher concurrency in read operations.
#             Default is "16" if not specified.
#             Example: export NUMJOBS="32"
#
#   SIZE - The size of the test file for each job. Affects the duration of the test
#          and can simulate different load sizes.
#          Default is "10G" if not specified.
#          Example: export SIZE="100G"
#
#   RUNTIME - The duration for which each job should run, overriding SIZE if both are specified.
#             Default is "60s" if not specified.
#             Example: export RUNTIME="120s"
#
#   RAMP_TIME - The warm-up time before measurements start. Useful for stabilizing the system before testing.
#               Default is "2s" if not specified.
#               Example: export RAMP_TIME="5s"
#
#   DIRECT - If set to "1", FIO will use direct I/O, bypassing the cache. For testing raw disk performance.
#            Default is "1" if not specified.
#            Example: export DIRECT="0" to use buffered I/O
#
#   VERIFY - Enables data verification. Not used in throughput testing by default.
#            Default is "0" if not specified.
#            Example: export VERIFY="1"
#
#   BS - Block size for read operations. Affects how data is read in terms of the size of each operation.
#        Default is "1M" if not specified.
#        Example: export BS="4k"
#
#   IODEPTH - The depth of the I/O queue. Higher values can improve performance by increasing I/O parallelism.
#             Default is "64" if not specified.
#             Example: export IODEPTH="128"
#
#   IODEPTH_BATCH_SUBMIT - Controls how many I/Os FIO should submit in one go. Tied to IODEPTH.
#                          Default is "64" if not specified.
#                          Example: export IODEPTH_BATCH_SUBMIT="32"
#
#   IODEPTH_BATCH_COMPLETE_MAX - Maximum number of I/Os to complete at once if IODEPTH > 1.
#                                Default is "64" if not specified.
#                                Example: export IODEPTH_BATCH_COMPLETE_MAX="32"
#
# Usage:
#   Configure the desired test parameters through environment variables, then execute this script.
#   Example command to run the script with default settings:
#   ./fio_seq_read.sh
##
# Output:
#   The script outputs the test results in JSON format for easy parsing and analysis.
#   Ensure to redirect output to a file if persistence is needed.
#
# Note: This script is designed for use on Linux systems with the FIO tool installed.


export BENCH_DIR="${TEST_DIR:-/tmp}"

fio --name=read_throughput \
--directory="${BENCH_DIR}" \
--numjobs="${NUMJOBS:-16}" \
--size="${SIZE:-10G}" \
--time_based \
--runtime="${RUNTIME:-60s}" \
--ramp_time="${RAMP_TIME:-2s}" \
--ioengine=libaio \
--direct="${DIRECT:-1}" \
--verify="${VERIFY:-0}" \
--bs="${BS:-1M}" \
--iodepth="${IODEPTH:-64}" --rw=read \
--group_reporting=1 \
--iodepth_batch_submit="${IODEPTH_BATCH_SUBMIT:-64}" \
--iodepth_batch_complete_max="${IODEPTH_BATCH_COMPLETE_MAX:-64}" \
--output-format json
