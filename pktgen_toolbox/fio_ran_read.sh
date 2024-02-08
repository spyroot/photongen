#!/bin/bash
# Basic script perform random read
# spyroot@gmail.com
# Author Mustafa Bayramov

export BENCH_DIR="${TEST_DIR:-/tmp}"

fio --name=read_iops \
--directory="${BENCH_DIR}" \
--size="${SIZE:-10G}" \
--time_based \
--runtime="${RUNTIME:-60s}" \
--ramp_time="${RAMP_TIME:-2s}" \
--ioengine=libaio \
--direct="${DIRECT:-1}" \
--verify="${VERIFY:-0}" \
--bs="${BS:-4K}" \
--iodepth="${IODEPTH:-256}" \
--rw=randread \
--group_reporting=1 \
--iodepth_batch_submit="${IODEPTH_BATCH_SUBMIT:-256}" \
--iodepth_batch_complete_max="${IODEPTH_BATCH_COMPLETE_MAX:-256}"
