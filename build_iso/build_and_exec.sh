wget -nc http://10.241.11.28/iso/photon/ph4-rt-refresh.iso
docker rm -f /photon_iso_builder
docker build -t photon_iso_builder:v1 .
docker run -v `pwd`:`pwd` -w `pwd` --privileged --name photon_iso_builder --rm -i -t photon_iso_builder:v1 bash
