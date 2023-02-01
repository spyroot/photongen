#!/bin/bash
# unpack iso , re-adjust kickstart , repack back iso.
# Author Mustafa Bayramov

current_os=$(uname -a)
if [[ $current_os == *"xnu"* ]]; 
then
  echo "You must run the script inside docker runtime."
exit 2
fi

DEFAULT_IMAGE_NAME="ph4-rt-refresh_adj.iso"

workspace_dir=$(pwd)
rm ph4-rt-refresh_adj.iso

umount /tmp/photon-iso
rm -rf /tmp/photon-iso
rm -rf /tmp/photon-ks-iso

mkdir /tmp/photon-iso
mount $DEFAULT_IMAGE_NAME /tmp/photon-iso

mkdir /tmp/photon-ks-iso
cp -r /tmp/photon-iso/* /tmp/photon-ks-iso/
cp docker_images/*.tar.gz /tmp/photon-ks-iso/

pushd /tmp/photon-ks-iso/ || exit
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
probe -s photondisk -u ($root)

menuentry "Install" {
    linux /isolinux/vmlinuz root=/dev/ram0 ks=cdrom:/isolinux/ks.cfg loglevel=3 photon.media=UUID=$photondisk
    initrd /isolinux/initrd.img
}
EOF

sed -i 's/default install/default my_unattended/g' /tmp/photon-ks-iso/isolinux/menu.cfg

mkisofs -R -l -L -D -b isolinux/isolinux.bin -c isolinux/boot.cat \
                -no-emul-boot -boot-load-size 4 -boot-info-table \
                -eltorito-alt-boot --eltorito-boot boot/grub2/efiboot.img -no-emul-boot \
                -V "PHOTON_$(date +%Y%m%d)" . > "$workspace_dir"/ph4-rt-refresh_adj.iso
popd || exit
umount /tmp/photon-iso
