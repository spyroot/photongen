#!/bin/bash
# Basic script perform seq read
# spyroot@gmail.com
# Author Mustafa Bayramov

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
--iodepth_batch_complete_max="${IODEPTH_BATCH_COMPLETE_MAX:-64}"
