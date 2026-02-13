#!/bin/bash
set -e

# fpin_li_control_sequence_script.sh  -- FPIN link integrity test script

# Prerequisite environment variables:
# FCSWITCH: "user@host" for fibre channel switch to control
# SSHPASS: sshpass variable for fibre channel switch
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

DELAY=5
POST_CHECK_DELAY=2

if [ ! "$1" ]
then
	echo "Usage: $0 <device>"
	echo "    (Run 'grep . /sys/class/fc_host/host*/port_* to display')"
	echo "     the port IDs used by this host.)"
	exit 2
fi

DEVPATH=$1

if [ ! "$FCSWITCH" ]
then
	echo "ERROR: Set the FCSWITCH variable with the username@host"
	echo "string for the fibre channel switch tosend FPIN events."
	exit 2
fi

# Scan for all fibre channel host port_id sysfs files
FCHOST_PORTIDS=$(grep . /sys/class/fc_host/host*/port_id | sed -e 's/:/\ /g')

echo "FC Host port IDs:"
echo "$FCHOST_PORTIDS"

check_inflight_per_path() {
	sleep $DELAY
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
	PORTID=$1
	if [ ! "$SSHPASS" ]
	then
		echo "Be sure to export the SSHPASS variable."
		exit 2
	fi

	sshpass -e ssh "$FCSWITCH" "/fabos/cliexec/ftc test --fpin $PORTID -li -$FPINTYPE"
}

reset_marginal_rport() {
	SCSIHOSTID=$1
	echo "Sending reset to $SCSIHOSTID..."
	echo "Online" | sudo tee /sys/class/fc_host/"$SCSIHOSTID"/device/rport*/fc_remote_ports/*/port_state
}

main_test_loop() {
	date

	echo "Sending FPIN Link Integrity event $FPINTYPE... host ${FCHOSTS[0]}..."
	send_fpin_link_integrity_event "${FCPORTIDS[0]}"
	check_inflight_per_path

	echo "Resetting marginal rports to online"
	reset_marginal_rport "${FCHOSTS[0]}"
	check_inflight_per_path

	echo "Sending FPIN Link Integrity event $FPINTYPE... host ${FCHOSTS[1]}..."
	send_fpin_link_integrity_event "${FCPORTIDS[1]}"
	check_inflight_per_path

	echo "Resetting marginal rports to online"
	reset_marginal_rport "${FCHOSTS[1]}"
	check_inflight_per_path

	echo "Sending FPIN Link Integrity event $FPINTYPE... both hosts..."
	send_fpin_link_integrity_event "${FCPORTIDS[0]}"
	send_fpin_link_integrity_event "${FCPORTIDS[1]}"
	check_inflight_per_path

	echo "Resetting marginal rports to online"
	reset_marginal_rport "${FCHOSTS[0]}"
	reset_marginal_rport "${FCHOSTS[1]}"
	check_inflight_per_path
}

readarray -t FCHOSTS <<< "$(grep . /sys/class/fc_host/host*/port_id | sed -e 's/.*fc_host//g' | sed -e 's/port_id.*//g' | tr -d /)"

readarray -t FCPORTIDS <<< "$(grep . /sys/class/fc_host/host*/port_id | sed -e 's/:/\ /g' | awk '{print $2}' | sed -e 's/0x//g')"

FPINTYPES=(unknown link_failure loss_sync loss_signal primitive_error itw crc dev_specific)
for FPINTYPE in "${FPINTYPES[@]}"
do
	main_test_loop
done
