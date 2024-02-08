docker save -o dpdk_generic_tester.tar cnfdemo.io/spyroot/dpdk_generic_tester:latest
docker save -o dpdk_native_tester.tar cnfdemo.io/spyroot/dpdk_native_tester:latest
gzip -c dpdk_generic_tester.tar > dpdk_generic_tester.tar.gz &
gzip -c dpdk_native_tester.tar > dpdk_native_tester.tar.gz &
sha256sum dpdk_generic_tester.tar.gz > dpdk_generic_tester.sha256
sha256sum dpdk_native_tester.tar.gz > dpdk_native_tester.sha256

