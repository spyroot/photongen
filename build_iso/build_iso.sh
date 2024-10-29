#!/bin/bash
# This script will build custom Photon OS ISO image
# for untended install. and name it to DEFAULT_DST_IMAGE_NAME,
# this value shared in shared.bash. unpack iso, re-adjust kickstart ,
# repack back iso.
#
# spyroot@gmail.com
# Author Mustafa Bayramov

source shared.bash

echo "$DEFAULT_SRC_IMAGE_NAME"
echo "$DEFAULT_DST_IMAGE_NAME"
USE_LFS="no"

DEFAULT_SRC_ISO_DIR="/tmp/photon-iso"
DEFAULT_DST_ISO_DIR="/tmp/photon-ks-iso"

log() {
  printf "%b %s. %b\n" "${GREEN}" "$@" "${NC}"
}

current_os=$(uname -a)
if [[ $current_os == *"xnu"* ]];
then
  echo "You must run the script inside docker runtime."
exit 2
fi

workspace_dir=$(pwd)
rm "$DEFAULT_DST_IMAGE_NAME" 2>/dev/null
umount -q "$DEFAULT_SRC_ISO_DIR"  2>/dev/null
rm -rf "$DEFAULT_SRC_ISO_DIR"  2>/dev/null
rm -rf /tmp/photon-ks-iso  2>/dev/null

mkdir -p "$DEFAULT_SRC_ISO_DIR"

log "Mount $DEFAULT_SRC_IMAGE_NAME to $DEFAULT_SRC_ISO_DIR"

if ! mount "$DEFAULT_SRC_IMAGE_NAME" "$DEFAULT_SRC_ISO_DIR"; then
  echo "Error: Failed to mount $DEFAULT_SRC_IMAGE_NAME" >&2
  exit 1
fi

mkdir -p "$DEFAULT_DST_ISO_DIR"
log "Copy data from $DEFAULT_SRC_ISO_DIR/* to $DEFAULT_DST_ISO_DIR/"
cp -r "$DEFAULT_SRC_ISO_DIR"/* "$DEFAULT_DST_ISO_DIR"/
cp docker_images/*.tar.gz "$DEFAULT_DST_ISO_DIR"/ 2>/dev/null || echo "Warning: No docker images found to copy."
cp post.sh "$DEFAULT_DST_ISO_DIR"/ 2>/dev/null || echo "Warning: No post.sh script found to copy."

mkdir -p "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_RPM_DST_DIR"
mkdir -p "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_GIT_DST_DIR"
mkdir -p "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_ARC_DST_DIR"

log "Copy rpms from $DEFAULT_RPM_DIR to $DEFAULT_DST_ISO_DIR / $DEFAULT_RPM_DST_DIR"
cp "$DEFAULT_RPM_DIR"/* "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_RPM_DST_DIR" || 2>/dev/null || echo "Warning: No RPMs found to copy."
log "Copy git tar.gz from $DEFAULT_GIT_DIR to $DEFAULT_DST_ISO_DIR / $DEFAULT_GIT_DST_DIR"
cp "$DEFAULT_GIT_DIR"/* "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_GIT_DST_DIR" || 2>/dev/null || echo "Warning: No Git tar.gz files found to copy."
log "Copy arcs from $DEFAULT_ARC_DIR to $DEFAULT_DST_ISO_DIR / $DEFAULT_ARC_DST_DIR"
cp "$DEFAULT_ARC_DIR"/* "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_ARC_DST_DIR" || 2>/dev/null || echo "Warning: No archive files found to copy."

pushd "$DEFAULT_DST_ISO_DIR"/ || exit
cp "$workspace_dir"/ks.cfg isolinux/ks.cfg

# generate isolinux
cat > isolinux/isolinux.cfg << EOF
include menu.cfg
default vesamenu.c32
prompt 1
timeout 1
EOF

# generate menu
cat >> isolinux/menu.cfg << EOF
label my_unattended
	menu label ^Unattended Install
    menu default
	kernel vmlinuz
	append initrd=initrd.img root=/dev/ram0 ks=cdrom:/isolinux/ks.cfg loglevel=3 photon.media=cdrom console=ttyS0
EOF

# generate grub
cat > boot/grub2/grub.cfg << EOF
set default=1
set timeout=1
loadfont ascii
set gfxmode="1024x768"
gfxpayload=keep

set theme=/boot/grub2/themes/photon/theme.txt
terminal_output gfxterm
probe -s photondisk -u (\$root)

menuentry "Install" {
    linux /isolinux/vmlinuz root=/dev/ram0 ks=cdrom:/isolinux/ks.cfg loglevel=3 photon.media=UUID=\$photondisk console=ttyS0
    initrd /isolinux/initrd.img
}
EOF

sed -i 's/default install/default my_unattended/g' /tmp/photon-ks-iso/isolinux/menu.cfg

mkisofs -quiet -R -l -L -D -b isolinux/isolinux.bin -c isolinux/boot.cat -log-file /tmp/mkisofs.log \
                -no-emul-boot -boot-load-size 4 -boot-info-table \
                -eltorito-alt-boot --eltorito-boot boot/grub2/efiboot.img -no-emul-boot \
                -V "PHOTON_$(date +%Y%m%d)" . > "$workspace_dir"/"$DEFAULT_DST_IMAGE_NAME"
popd || exit
umount "$DEFAULT_SRC_ISO_DIR"
log "Generated ISO in $workspace_dir/$DEFAULT_DST_IMAGE_NAME"

# Verification of the generated ISO
log "Generated ISO in $workspace_dir/$DEFAULT_DST_IMAGE_NAME"
if [ -f "$workspace_dir/$DEFAULT_DST_IMAGE_NAME" ] && [ -s "$workspace_dir/$DEFAULT_DST_IMAGE_NAME" ]; then
  log "ISO successfully created: $workspace_dir/$DEFAULT_DST_IMAGE_NAME"
else
  echo "Error: ISO generation failed or file is empty." >&2
  exit 1
fi

#  if ISO is bootable
if isoinfo -d -i "$workspace_dir/$DEFAULT_DST_IMAGE_NAME" | grep -iq "bootable"; then
  log "ISO is bootable."
else
  echo "Warning: ISO may not be bootable." >&2
fi

isoinfo -R -l -i "$workspace_dir/$DEFAULT_DST_IMAGE_NAME"

isoinfo -l -R -i "$workspace_dir/$DEFAULT_DST_IMAGE_NAME" | grep -E 'isolinux/ks.cfg|isolinux/isolinux.cfg|boot/grub2/grub.cfg' || echo "Warning: Some expected files may be missing in the ISO."
log "ISO Size: $(du -h "$workspace_dir/$DEFAULT_DST_IMAGE_NAME" | cut -f1)"

GITHUB_REPO="spyroot/photongen"
GITHUB_TOKEN="your_github_token"
GITHUB_PATH="$DEFAULT_DST_IMAGE_NAME"

# After generating the ISO
log "ISO successfully created: $workspace_dir/$DEFAULT_DST_IMAGE_NAME"

GITHUB_REPO="spyroot/photongen"
GITHUB_TOKEN="your_github_token"
GITHUB_PATH="$DEFAULT_DST_IMAGE_NAME"

# After generating the ISO
log "ISO successfully created: $workspace_dir/$DEFAULT_DST_IMAGE_NAME"

if [ "$USE_LFS" == "yes" ]; then
  git config --global user.email "spyroot@gmail.com"
  git config --global user.name "spyroot"

  BRANCH_NAME="upload-iso-$(date +%Y%m%d)"
  git checkout -b "$BRANCH_NAME"

  if [ ! -d ".git" ]; then
    git init
  fi

  git lfs track "$DEFAULT_DST_IMAGE_NAME"
  git add .gitattributes
  git add "$workspace_dir/$DEFAULT_DST_IMAGE_NAME"
  git commit -m "Add ISO file to LFS: $DEFAULT_DST_IMAGE_NAME"
  git push https://"$GITHUB_TOKEN"@github.com/"$GITHUB_REPO".git "$BRANCH_NAME"
  log "ISO pushed to GitHub: https://github.com/$GITHUB_REPO/tree/$BRANCH_NAME"
fi
