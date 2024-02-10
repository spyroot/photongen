docker run -e MODE=server -e PORT=5001 -it --privileged \
--rm spyroot/pktgen_toolbox_generic:latest /fio_random_writes.sh