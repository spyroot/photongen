docker save -o pktgen_toolbox_generic.tar spyroot/pktgen_toolbox_generic:latest
gzip -c pktgen_toolbox_generic.tar > pktgen_toolbox_generic.tar.gz && rm pktgen_toolbox_generic.tar
sha256sum pktgen_toolbox_generic.tar.gz > pktgen_toolbox_generic.sha256
