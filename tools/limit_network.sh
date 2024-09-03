#!/bin/bash

# WARNNING: 禁用公网访问、禁用访问公网，用于模拟客户的无互联网访问的环境

iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT
iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -s 173.20.0.1/16 -j ACCEPT
iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -j DROP

iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 173.20.0.1/16 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/24 -j ACCEPT
iptables -A OUTPUT -j DROP
