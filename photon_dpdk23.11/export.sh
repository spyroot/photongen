  docker save -o dpdk_tester.tar cnfdemo.io/spyroot/dpdk_tester:latest\n
  docker run -it cnfdemo.io/spyroot/dpdk_tester:latest /bin/bash
  gzip dpdk_tester.tar \n
  gzip -c dpdk_tester.tar > dpdk_tester.tar.gz
