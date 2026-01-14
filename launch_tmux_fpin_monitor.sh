#!/bin/bash

if [ ! "$1" ] || [ ! "$2" ]
	then
	echo "Usage: $0 <device> <subsys>"
	exit 2
fi

DEVPATH=$1
SUBSYS=$2
DEVNAME=$(basename "$DEVPATH")
SESSION_NAME="fpin_mon"

set -x
tmux new-session -d -s "$SESSION_NAME" "watch -t -d 'grep . /sys/class/fc_host/host*/port_*; grep -H . /sys/devices/virtual/nvme-subsystem/$SUBSYS/iopolicy'"
tmux split-window -v -t "$SESSION_NAME" "watch -t -d 'grep . /sys/devices/virtual/nvme-subsystem/$SUBSYS/$DEVNAME/multipath/*/stat; echo; sudo nvme list-subsys $DEVPATH'"
tmux split-window -h -t "$SESSION_NAME:0.0"
tmux split-window -v -t "$SESSION_NAME:0.0" "watch -t -d 'grep .  /sys/class/fc_host/host*/device/rport-*/fc_remote_ports/rport*/port_state'"
set +x

echo ""
echo "use \"xterm -e sudo fio --name=80Grandreadwrite --filename $DEVPATH --rw=randrw --bs=4096 --direct=1 --unlink=0 --iodepth=32 --ioengine=libaio --scramble_buffers=1 --randrepeat=1 --norandommap --size=80G --time_based=1 --runtime=86400s\""
echo ""
echo ""
echo "use \"tmux attach\" to connect to session"
echo ""

