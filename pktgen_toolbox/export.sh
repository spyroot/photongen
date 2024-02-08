docker save -o pktgen_toolbox.tar cnfdemo.io/spyroot/pktgen_toolbox:latest
gzip -c pktgen_toolbox.tar > pktgen_toolbox.tar.gz &
sha256sum pktgen_toolbox.tar.gz > pktgen_toolbox.sha256