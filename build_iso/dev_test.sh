#!/bin/bash
docker build -t spyroot/photon_iso_builder:latest . --platform linux/amd64


#
#
#[
#"echo v=\"$(ls /mnt/cdrom/direct_rpms/*.rpm | wc -l)\"; echo \"number of rpms in cdrom $v\"\necho v=\"$(ls /mnt/media/direct_rpms/*.rpm | wc -l)\";,
#echo \"number of rpms in cdrom $v\,
#"\necho \"Installing rpms from media\"; tdnf install -y /mnt/media/direct_rpms/*.rpm\ntdnf \"Installing rpms from cdrom\"; install -y /mnt/cdrom/direct_rpms/*.rpm\ntdnf \"Installing rpms from tmp\"; install -y /tmp/direct_rpms/*.rpm\necho \"copy direct_rpms from /mnt/media\"; mkdir -p /direct_rpms; cp /mnt/media/direct_rpms/*.rpm /direct_rpms\necho \"copy direct_rpms from /mnt/cdrom\"; mkdir -p /direct_rpms; cp /mnt/cdrom/direct_rpms/*.rpm /direct_rpms\necho \"copy direct from /mnt/media\"; mkdir -p /direct; cp /mnt/media/direct/* /direct\necho \"copy direct from /mnt/cdrom rpms\"; mkdir -p direct; cp /mnt/cdrom/direct/* /direct\necho \"copy git_images from /mnt/media\"; mkdir -p /git_images; cp /mnt/media/git_images/* /git_images\necho \"copy git_images from /mnt/cdrom\"; mkdir -p /git_images; cp /mnt/cdrom/git_images/* /git_images"]