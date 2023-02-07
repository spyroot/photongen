#!/bin/bash
# This script will build custom ISO image.
# and name it to DEFAULT_DST_IMAGE_NAME, this value shared in shared.bash.
# unpack iso, re-adjust kickstart , repack back iso.
#
#
# spyroot@gmail.com
# Author Mustafa Bayramov

source shared.bash

echo "$DEFAULT_SRC_IMAGE_NAME"
echo "$DEFAULT_DST_IMAGE_NAME"

DEFAULT_SRC_ISO_DIR="/tmp/photon-iso"
DEFAULT_DST_ISO_DIR="/tmp/photon-ks-iso"

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

echo "Mount $DEFAULT_SRC_IMAGE_NAME to $DEFAULT_SRC_ISO_DIR"
mount "$DEFAULT_SRC_IMAGE_NAME" "$DEFAULT_SRC_ISO_DIR" 2>/dev/null

mkdir -p /tmp/photon-ks-iso
echo "Copy data from $DEFAULT_SRC_ISO_DIR/* to $DEFAULT_DST_ISO_DIR/"

cp -r "$DEFAULT_SRC_ISO_DIR"/* "$DEFAULT_DST_ISO_DIR"/
cp docker_images/*.tar.gz "$DEFAULT_DST_ISO_DIR"/
cp post.sh "$DEFAULT_DST_ISO_DIR"/

mkdir -p "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_RPM_DST_DIR"
mkdir -p "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_GIT_DST_DIR"
mkdir -p "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_ARC_DST_DIR"

cp $DEFAULT_RPM_DIR/* "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_RPM_DST_DIR"
cp $DEFAULT_GIT_DIR/* "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_GIT_DST_DIR"
cp $DEFAULT_ARC_DIR/* "$DEFAULT_DST_ISO_DIR"/"$DEFAULT_ARC_DST_DIR"

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
	append initrd=initrd.img root=/dev/ram0 ks=cdrom:/isolinux/ks.cfg loglevel=3 photon.media=cdrom
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
    linux /isolinux/vmlinuz root=/dev/ram0 ks=cdrom:/isolinux/ks.cfg loglevel=3 photon.media=UUID=\$photondisk
    initrd /isolinux/initrd.img
}
EOF

sed -i 's/default install/default my_unattended/g' /tmp/photon-ks-iso/isolinux/menu.cfg

mkisofs -R -l -L -D -b isolinux/isolinux.bin -c isolinux/boot.cat \
                -no-emul-boot -boot-load-size 4 -boot-info-table \
                -eltorito-alt-boot --eltorito-boot boot/grub2/efiboot.img -no-emul-boot \
                -V "PHOTON_$(date +%Y%m%d)" . > "$workspace_dir"/$DEFAULT_DST_IMAGE_NAME
popd || exit
umount "$DEFAULT_SRC_ISO_DIR"