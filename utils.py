#!/usr/bin/env python3

# Copyright (c) 2021 VMware, Inc. All rights reserved.

import pathlib
from typing import Generator, List, Tuple


def get_devices_by_vendor_id_device_id(
        dev_ids: List[Tuple[str]]) -> Generator[str, None, None]:
    """Generates all devices matching the list of vendor ID and device ID
    """

    for device_dir in pathlib.Path("/sys/bus/pci/devices").iterdir():
        dev_vendor_id = (device_dir / "vendor").read_text().strip()
        dev_device_id = (device_dir / "device").read_text().strip()

        device_matched = False
        for vendor_id, device_id in dev_ids:
            if dev_vendor_id == vendor_id and dev_device_id == device_id:
                device_matched = True
                break

        if not device_matched:
            continue

        yield device_dir.name


FEC_ACCEL_DEVICES = [
    ("0x8086", "0x0d8f"),  # N3000
    ("0x8086", "0x0d5d"),  # ACC100
]


def get_fec_accel_devices():
    return get_devices_by_vendor_id_device_id(FEC_ACCEL_DEVICES)


ETH_DEVICES = [
    ("0x8086", "0x0d58"),  # N3000 Ethernet
    ("0x8086", "0x1889"),  # Intel E810-C for SFP VF
]


def get_eth_devices():
    return get_devices_by_vendor_id_device_id(ETH_DEVICES)


ISOL_CPUS_PATH = "/sys/devices/system/cpu/isolated"


def get_isol_cpus_text() -> str:
    return pathlib.Path(ISOL_CPUS_PATH).read_text().strip()


def get_items_from_range_text(ranges_text: str) -> Generator[int, None, None]:
    if not ranges_text:
        return

    for min, max in [
            (int(item) for item in range_text.split("-"))
            for range_text in ranges_text.split(",")]:
        for item in range(min, max + 1):
            yield item


def get_isol_cpus() -> Generator[int, None, None]:
    return get_items_from_range_text(get_isol_cpus_text())
