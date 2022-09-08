#!/bin/bash

current_os=$(uname -a)
if [[ $current_os == *"xnu"* ]]; 
then
echo "You must run the script inside docker runtime."
exit 2
fi


workspace_dir=$(pwd)
rm ph4-rt-refresh_adj.iso

umount /tmp/photon-iso
rm -rf /tmp/photon-iso
rm -rf /tmp/photon-ks-iso

mkdir /tmp/photon-iso
mount ph4-rt-refresh.iso /tmp/photon-iso

mkdir /tmp/photon-ks-iso
cp -r /tmp/photon-iso/* /tmp/photon-ks-iso/
pushd /tmp/photon-ks-iso/
cp $workspace_dir/ks.cfg isolinux/ks.cfg

cat >> isolinux/menu.cfg << EOF
default my_unattended
label my_unattended
	menu label ^Unattended Install
	kernel vmlinuz
	append initrd=initrd.img root=/dev/ram0 ks=cdrom:/isolinux/ks.cfg loglevel=3 photon.media=cdrom
EOF

cat >> boot/grub2/grub.cfg << EOF
GRUB_TIMEOUT=0
set default=0
set timeout=0
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

mkisofs -R -l -L -D -b isolinux/isolinux.bin -c isolinux/boot.cat \
                -no-emul-boot -boot-load-size 4 -boot-info-table \
                -eltorito-alt-boot --eltorito-boot boot/grub2/efiboot.img -no-emul-boot \
                -V "PHOTON_$(date +%Y%m%d)" . > $workspace_dir/ph4-rt-refresh_adj.iso
popd
