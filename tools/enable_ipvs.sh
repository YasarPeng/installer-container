#!/bin/bash

cat <<EOF > /etc/modules-load.d/ipvs.conf
# https://github.com/kubernetes/kubernetes/tree/master/pkg/proxy/ipvs
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
ip_tables
br_netfilter
bridge
nf_nat
nf_conntrack
EOF

systemctl restart systemd-modules-load.service

