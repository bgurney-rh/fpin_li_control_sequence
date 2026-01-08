#!/bin/bash
set -e

# fpin_li_control_sequence_script.sh  -- FPIN link integrity test script

# TODO: SSHPASS needs to be set to a value; set to empty string for now.
#
# Prerequisite environment variables:
# FCSWITCH: "user@host" for fibre channel switch to control
# STORARRAY: "user@host" for storage array to control
# SWITCH_SSHPASS: sshpass variable for fibre channel switch
# ARRAY_SSHPASS: sshpass variable for storage array (currently NetApp only)
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
# 2: Driver of host bus adapter to control
# 3: Port ID on fibre channel switch to send FPIN event
# 4: non-marginal optimized interface on storage array to control
#
# Example:
# $ bash fpin_li_control_sequence_script.sh /dev/nvme4n1 qla2xxx 021700 fc1_01_5d

# TODO: hardcoded items
# - qla2xxx: bus address of HBA to unbind and bind
#
# Interesting items to find:
# - primary array controller (ANA state "optimized")
# - lowest host port ID (may not correspond to lowest fc_host)
#

DEV_LOSS_TMO=30
POST_CHECK_DELAY=2

if [ ! "$1" ] || [ ! "$2" ] || [ ! "$3" ]
then
	echo "Usage: $0 <device> <driver> <scsi_host_id> <port_id> <non_marginal_opt_path>"
	echo "WARNING: Be sure to use the correct port ID for this host."
	echo "(Run 'grep . /sys/class/fc_host/host*/port_* to display')"
	exit 2
fi

DEVPATH=$1
DRIVER=$2
SCSIHOSTID=$3
PORTID=$4
NON_MARGINAL_OPTIMIZED=$5

if [ ! "$FCSWITCH" ] || [ ! "$STORARRAY" ]
then
	echo "ERROR: Set the FCSWITCH and STORARRAY variables with the"
	echo "username@host string for the fibre channel switch to"
	echo "send FPIN events, and the storage array to control"
	echo "array-side port states."
	exit 2
fi

if [ ! "$SWITCH_SSHPASS" ] || [ ! "$ARRAY_SSHPASS" ]
then
	echo "Be sure to export the SWITCH_SSHPASS and ARRAY_SSHPASS"
	echo "variables for the switch and array credentials, for the"
	echo "'sshpass -e' commands."
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

control_target_path() {
	SSHPASS=$ARRAY_SSHPASS
	if [ ! "$SSHPASS" ]
	then
		echo "Be sure to export the ARRAY_SSHPASS variable"
		exit 2
	fi
	date; sshpass -e ssh "$STORARRAY" "net int modify -vserver fcqe1 -lif $NON_MARGINAL_OPTIMIZED -status-admin $PATH_STATE"
}

control_host_port_down() {
	case $DRIVER in
	"qla2xxx")
		date; echo "0000:b4:00.0" | sudo tee /sys/bus/pci/drivers/qla2xxx/unbind
	;;
	"lpfc")
		date; echo "down" | sudo tee /sys/class/scsi_host/"$SCSIHOSTID"/link_state
	;;
	esac
}

control_host_port_up() {
	case $DRIVER in
	"qla2xxx")
		date; echo "0000:b4:00.0" | sudo tee /sys/bus/pci/drivers/qla2xxx/bind
	;;
	"lpfc")
		date; echo "up" | sudo tee /sys/class/scsi_host/"$SCSIHOSTID"/link_state
	;;
	esac
}

reset_marginal_rport() {
	echo "Online" | sudo tee /sys/class/fc_host/"$SCSIHOSTID"/device/rport*/fc_remote_ports/*/port_state
}


date
echo "Driver: $DRIVER"

case $DRIVER in
"qla2xxx")
	echo "Using qla2xxx; requires unbind/bind for port control"
	;;
"lpfc")
	echo "Using lpfc; can use scsi_host link_state sysfs file for control"
	;;
*)
	echo "Unknown driver; use 'qla2xxx' or 'lpfc'"
	exit 4
	;;
esac

echo "Sending FPIN Link Integrity event..."
send_fpin_link_integrity_event
check_inflight_per_path

echo "Resetting marginal rports to online"
reset_marginal_rport
check_inflight_per_path
