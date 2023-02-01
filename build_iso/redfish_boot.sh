source set_env.sh
# Example one shoot boot from ISO
pip install idrac_ctl
idrac_ctl get_vm
idrac_ctl eject_vm --device_id 1
# confirm
idrac_ctl get_vm

# insert virtual media
idrac_ctl insert_vm --uri_path http://"$IDRAC_REMOTE_HTTP"/ph4-rt-refresh_adj.iso --device_id 1
# check
idrac_ctl.py get_vm

# adjust one shoot boot setting and reboot host.  it will boot from virtual media.
python idrac_ctl.py boot-one-shot --device Cd -r