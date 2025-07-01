#/bin/bash

echo br_netfilter > /etc/modules-load.d/br_netfilter.conf
systemctl restart systemd-modules-load.service

# 解决noekylin v7启用br_netfilter失败的问题
cat <<EOF > /etc/sysctl.d/99-enable_br_netfilter.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system > /dev/null
