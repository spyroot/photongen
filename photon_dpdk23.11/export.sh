docker save -o dpdk_tester.tar cnfdemo.io/spyroot/dpdk_generic_tester:latest
gzip dpdk_generic_tester.tar
gzip -c dpdk_generic_tester.tar > dpdk_generic_tester.tar.gz

docker save -o dpdk_tester.tar cnfdemo.io/spyroot/dpdk_native_tester:latest
gzip dpdk_native_tester.tar
gzip -c dpdk_native_tester.tar > dpdk_native_tester.tar.gz
