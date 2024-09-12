#!/bin/bash

cat <<EOF > /etc/sysctl.d/99-container.conf
# 
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288

net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1

EOF

systemctl restart systemd-modules-load.service

