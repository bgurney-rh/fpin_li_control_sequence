#!/bin/bash
set -x

if [ ! "$1" ] || [ ! "$2" ]
	then
	echo "Usage: $0 <device> <subsys>"
	exit 2
fi

DEVPATH=$1
SUBSYS=$2
DEVNAME=$(basename "$DEVPATH")


SESSION_NAME="fpin_mon"

tmux new-session -d -s "$SESSION_NAME" "watch -t -d 'grep . /sys/class/fc_host/host*/port_*; grep -H . /sys/devices/virtual/nvme-subsystem/$SUBSYS/iopolicy'"

tmux split-window -v -t "$SESSION_NAME" "watch -t -d 'grep . /sys/devices/virtual/nvme-subsystem/$SUBSYS/$DEVNAME/multipath/*/stat; echo; sudo nvme list-subsys $DEVPATH'"
tmux split-window -h -t "$SESSION_NAME:0.0"
tmux split-window -v -t "$SESSION_NAME:0.0" "watch -t -d 'grep .  /sys/class/fc_host/host*/device/rport-*/fc_remote_ports/rport*/port_state'"

