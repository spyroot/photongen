#!/bin/bash
# This script builds, modifies, and tests a custom ISO in QEMU for post-build checks.
# Main purpose is to validate the unattended install and adjust disk types as needed.
#
# Author Mustafa Bayramov
# mustafa.bayramov@broadcom.com

DISK_SIZE="20G"
DISK_FILE="disk.img"
ISO_FILE="/app/ph5-rt-refresh_adj.iso"
MODIFIED_ISO="modified_photon.iso"

DISK_TYPE="${DISK_TYPE:-virtio}"  # Default to virtio if DISK_TYPE is not set
DEFAULT_DISK_DEVICE="/dev/sda"    # Default device for ide
VIRTIO_DISK_DEVICE="/dev/vda"     # Device name for virtio

# Log messages with colors
log() {
  echo -e "\033[1;32m$1\033[0m" # Bold green text
}

# Ensure required binaries are installed
if ! command -v qemu-system-x86_64 &> /dev/null || ! command -v genisoimage &> /dev/null; then
  echo "Error: qemu-system-x86_64 or genisoimage is not installed."
  exit 1
fi

log "Building ISO..."
./build_iso.sh || { echo "Error: build_iso.sh failed."; exit 1; }

# Check if the ISO file was created
if [ ! -f "$ISO_FILE" ]; then
  echo "Error: ISO file not found at $ISO_FILE."
  exit 1
fi

# Create the virtual disk if it doesn’t already exist
if [ ! -f "$DISK_FILE" ]; then
  log "Creating virtual disk: $DISK_FILE with size $DISK_SIZE"
  qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
fi

# Determine the correct disk device
DISK_DEVICE=$([ "$DISK_TYPE" == "virtio" ] && echo "$VIRTIO_DISK_DEVICE" || echo "$DEFAULT_DISK_DEVICE")
log "Selected disk device: $DISK_DEVICE"

TEMP_ISO_DIR=$(mktemp -d)
MODIFIED_ISO_DIR=$(mktemp -d)

log "Mounting original ISO..."
mount -o loop "$ISO_FILE" "$TEMP_ISO_DIR" || { echo "Failed to mount ISO."; exit 1; }

log "Copying ISO contents to temporary directory..."
cp -rT "$TEMP_ISO_DIR" "$MODIFIED_ISO_DIR" || { echo "Failed to copy ISO contents."; sudo umount "$TEMP_ISO_DIR"; exit 1; }
umount "$TEMP_ISO_DIR"
rm -r "$TEMP_ISO_DIR"

KS_FILE_PATH="$MODIFIED_ISO_DIR/isolinux/ks.cfg"
if [ ! -f "$KS_FILE_PATH" ]; then
  echo "Error: ks.cfg file is missing in the ISO structure."
  exit 1
fi

log "Modifying ks.cfg to set disk device to $DISK_DEVICE..."
sed -i "s|\"disk\": \"/dev/sda\"|\"disk\": \"$DISK_DEVICE\"|g" "$KS_FILE_PATH"

log "Modified ks.cfg content:"
cat "$KS_FILE_PATH"

# Recreate the ISO with the modified ks.cfg , we need to swap virtia disk
log "Creating modified ISO with updated ks.cfg..."
genisoimage -quiet -R -J -l -V "MODIFIED_PHOTON" -o "$MODIFIED_ISO" -b isolinux/isolinux.bin \
  -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table "$MODIFIED_ISO_DIR" || { echo "Failed to create modified ISO."; rm -r "$MODIFIED_ISO_DIR"; exit 1; }

# Clean up
rm -r "$MODIFIED_ISO_DIR"

log "Starting QEMU with modified ISO and disk..."
qemu-system-x86_64 -m 2048 -nographic -serial mon:stdio \
  -boot d \
  -drive id=cdrom,media=cdrom,file="$MODIFIED_ISO",if=none \
  -device ahci,id=ahci -device ide-cd,drive=cdrom,bus=ahci.0 \
  -drive file="$DISK_FILE",format=qcow2,if="$DISK_TYPE" \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0

