# fpin_li_control_sequence

FPIN link integrity control sequence script
(As demonstrated at the ALPSS 2025 conference)

NOTE: This script is a work in progress, and may see various changes
as improvements are made.

```
Usage: ./launch_tmux_fpin_monitor.sh <device> <subsys>
```

Use `tmux attach` to attach to the tmux window
Use `Ctrl-b ?` for tmux help. Use `q` to exit help window
Use `Ctrl-d` to detach to tmux

Example:

```
rhel-storage-110:fpin_li_control_sequence(johnm_1) > nvme list-subsys /dev/nvme5n1
nvme-subsys5 - NQN=nqn.2020-07.com.hpe:ac31c249-6291-4ddc-b4d3-8aa162698dbf
               hostnqn=nqn.2014-08.org.nvmexpress:uuid:9df4225d-3935-479f-9aa3-08e2e0061b92
\
 +- nvme11 fc traddr=nn-0x2ff70102ac02cb4a:pn-0x20120102adf2cb4a,host_traddr=nn-0x200000109b954ecf:pn-0x100000109b954ecf live optimized
 +- nvme2 fc traddr=nn-0x2ff70102ac02cb4a:pn-0x21110102adf2cb4a,host_traddr=nn-0x200000109b954ed0:pn-0x100000109b954ed0 live non-optimized
 +- nvme3 fc traddr=nn-0x2ff70102ac02cb4a:pn-0x20110102adf2cb4a,host_traddr=nn-0x200000109b954ed0:pn-0x100000109b954ed0 live optimized
 +- nvme5 fc traddr=nn-0x2ff70102ac02cb4a:pn-0x21120102adf2cb4a,host_traddr=nn-0x200000109b954ecf:pn-0x100000109b954ecf live non-optimized

rhel-storage-110:fpin_li_control_sequence(johnm_1) > ./launch_tmux_fpin_monitor.sh /dev/nvme5n1 nvme-subsys5
+ tmux new-session -d -s fpin_mon 'watch -t -d '\''grep . /sys/class/fc_host/host*/port_*; grep -H . /sys/devices/virtual/nvme-subsystem/nvme-subsys5/iopolicy'\'''
+ tmux split-window -v -t fpin_mon 'watch -t -d '\''grep . /sys/devices/virtual/nvme-subsystem/nvme-subsys5/nvme5n1/multipath/*/stat; echo; sudo nvme list-subsys /dev/nvme5n1'\'''
+ tmux split-window -h -t fpin_mon:0.0
+ tmux split-window -v -t fpin_mon:0.0 'watch -t -d '\''grep .  /sys/class/fc_host/host*/device/rport-*/fc_remote_ports/rport*/port_state'\'''

rhel-storage-110:fpin_li_control_sequence(johnm_1) > tmux attach
```

