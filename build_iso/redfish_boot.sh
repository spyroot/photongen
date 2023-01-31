# Example one shoot boot from ISO
python idrac_ctl.py get_vm
python idrac_ctl.py eject_vm --device_id 1
# confirm
python idrac_ctl.py get_vm

# insert virtual media
python idrac_ctl.py insert_vm --uri_path http://$MY_IP/ubuntu-22.04.1-desktop-amd64.iso --device_id 1
# check
python idrac_ctl.py get_vm

# adjust one shoot boot setting and reboot host.  it will boot from virtual media.
python idrac_ctl.py boot-one-shot --device Cd -r