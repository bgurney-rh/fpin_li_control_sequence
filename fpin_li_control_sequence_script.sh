#!/bin/bash
set -e

# fpin_li_control_sequence_script.sh  -- FPIN link integrity test script

# TODO: SSHPASS needs to be set to a value; set to empty string for now.
#
# Prerequisite environment variables:
# FCSWITCH: "user@host" for fibre channel switch to control
# SWITCH_SSHPASS: sshpass variable for fibre channel switch
#
# Launch the tmux creation script first, using the NVMe device and
# subsystem for the test namespace:
#
# $ launch_tmux_fpin_monitor.sh /dev/nvme4n1 nvme-subsys4
#
# ...then, in another terminal, run "tmux attach"
#
# fpin_li_control_sequence_script.sh parameters:
# 1: Device node for test namespace.
# 2: SCSI FC host ID to control
# 3: Port ID on fibre channel switch to send FPIN event
# 4: non-marginal optimized interface on storage array to control
#
# Example:
# $ bash fpin_li_control_sequence_script.sh /dev/nvme4n1 qla2xxx 021700 fc1_01_5d
#
# Interesting items to find:
# - primary array controller (ANA state "optimized")
# - lowest host port ID (may not correspond to lowest fc_host)
#

DEV_LOSS_TMO=30
POST_CHECK_DELAY=2

if [ ! "$1" ] || [ ! "$2" ] || [ ! "$3" ]
then
	echo "Usage: $0 <device> <scsi_host_id> <port_id>"
	echo "WARNING: Be sure to use the correct port ID for this host."
	echo "(Run 'grep . /sys/class/fc_host/host*/port_* to display')"
	exit 2
fi

DEVPATH=$1
SCSIHOSTID=$2
PORTID=$3

if [ ! "$FCSWITCH" ]
then
	echo "ERROR: Set the FCSWITCH variable with the username@host"
	echo "string for the fibre channel switch tosend FPIN events."
	exit 2
fi

if [ ! "$SWITCH_SSHPASS" ]
then
	echo "Be sure to export the SWITCH_SSHPASS variable for the"
	echo "switch credentials, for the 'sshpass -e' command."
	exit 2
fi

check_inflight_per_path() {
	sleep $DEV_LOSS_TMO
	nvme list-subsys "$DEVPATH"
	for ns_stat in /sys/devices/virtual/nvme-fabrics/ctl/*/nvme*/stat
	do
		echo -n "$ns_stat: "
		awk "{print \$9}" < "$ns_stat"
	done
	echo
	sleep $POST_CHECK_DELAY
}

send_fpin_link_integrity_event() {
	SSHPASS=$SWITCH_SSHPASS
	if [ ! "$SSHPASS" ]
	then
		echo "Be sure to export the SWITCH_SSHPASS variable"
		exit 2
	fi
	sshpass -e ssh "$FCSWITCH" "/fabos/cliexec/ftc test --fpin $PORTID -li -primitive_error"
}

reset_marginal_rport() {
	echo "Online" | sudo tee /sys/class/fc_host/"$SCSIHOSTID"/device/rport*/fc_remote_ports/*/port_state
}


date

echo "Sending FPIN Link Integrity event..."
send_fpin_link_integrity_event
check_inflight_per_path

echo "Resetting marginal rports to online"
reset_marginal_rport
check_inflight_per_path
