#!/bin/bash
# 修改前请请联系系统管理员，确认不会影响系统配置

# 以下第4~32行的内容直接全部复制执行即可，无需按单个命令执行
cat << EOF > /etc/sysctl.d/kc.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
net.netfilter.nf_conntrack_max = 2097152
net.core.rmem_default=8388608
net.core.wmem_default=8388608
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rps_sock_flow_entries = 32768
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_mem = 1515357 2020479 3030714
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_orphans = 262144
net.ipv4.vs.sync_qlen_max = 505133
user.max_ipc_namespaces = 252888
user.max_mnt_namespaces = 252888
user.max_net_namespaces = 252888
user.max_pid_namespaces = 252888
user.max_uts_namespaces = 252888
vm.swappiness=0
vm.max_map_count = 655350
EOF

# 执行完以上命令后，再执行以下命令来让配置生效
sysctl -p /etc/sysctl.d/kc.conf

# 执行完之后，可以通过以下命令来查看系统参数，确认是否修改成功
# sysctl --system
