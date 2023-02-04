#!/bin/bash
# Extended LVM.
#
# spyroot@gmail.com
# Author Mustafa Bayramov

EXTENDED_DISK="yes"

# disk need extended
DEV_DISK_PATH="/dev/sda"
DISK_TO_EXTENDED="/dev/sda3"
DISK="sda3"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# log green
log_green() {
  printf "%b %s. %b\n" "${GREEN}" "$@" "${NC}"
}

# log red
log_red() {
  printf "%b %s. %b\n" "${RED}" "$@" "${NC}"
}

# upgrade disk
echo 1 > /sys/class/block/$DISK/device/rescan > /dev/null 2>&1

# extended LVM disk,  note if you change disk size for VM.
# reboot before executing this script.
if [ -z "$EXTENDED_DISK" ]
then
	log_green "Disk not found." exit 99;
else
  if [ $EXTENDED_DISK == "yes" ]
  then
    # fix disk
    DISK_TO_BE_EXT=$(pvdisplay | grep $DISK_TO_EXTENDED| awk '{ print $3 }')
    if [ -z "$DISK_TO_BE_EXT" ]
    then
      	log_red "Can't find $DISK_TO_EXTENDED."
    else
        # get disk number i.e /dev/sda3 - 3
        DISK_NUM="${DISK_TO_BE_EXT:0-1}"
        # let parted fix to 100% and rescan
        parted --fix $DEV_DISK_PATH "resizepart $DISK_NUM 100%"; pvscan
        # diskplay
        pvdisplay "$DISK_EXT"
        # get dev path
        DEV_PATH=$(lvdisplay | grep Path | awk '{ print $3 }')
        log_green "Resizing disk $DEV_PATH"
        # resize pv
        pvresize $DISK_TO_EXTENDED
        log_green "Extending disk $DEV_PATH"
        # resize lv
        lvextend -l +100%FREE "$DEV_PATH"
        # do check
        e2fsck -f "$DEV_PATH"
        #
        resize2fs "$DEV_PATH"
    fi
  else
    log_green "Skipping disk extended phase."
  fi
fi