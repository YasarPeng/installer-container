#!/bin/bash

# INFO: 某些操作系统发行版的某些版本，默认通过 /etc/sysctl.conf 关闭了 ip_forward

# kylin 默认在这个文件中禁用ip_forward
sed -i '/net.ipv4.ip_forward/ s/0/1/g' /etc/sysctl.conf

# ubuntu 启用ip_forward
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-enable_ipv4_forward.conf

sysctl --system > /dev/null
