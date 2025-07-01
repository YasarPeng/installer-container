#!/bin/bash

# Stop firewall
stop_and_disable_firewall() {
    if [ -f /etc/debian_version ]; then
        systemctl stop ufw.service
        systemctl disable ufw.service
    elif [ -f /etc/redhat-release ]; then
        systemctl stop firewalld
        systemctl disable firewalld
    elif [ -f /etc/kylin-release ]; then
        systemctl stop firewalld
        systemctl disable firewalld
    else
        warn "The current system type is unknown and the firewall cannot be turned off. Skip step."
    fi
}

stop_and_disable_firewall