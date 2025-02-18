#!/bin/bash

[[ $# != 1 ]] && echo "Usage: bash non-root.sh USERNAME" && exit -1

# nerdctl
chown root:$1 /usr/local/bin/nerdctl
chmod 755 /usr/local/bin/nerdctl
chmod +s /usr/local/bin/nerdctl

# docker
chmod 755 /usr/bin/docker
chmod 755 /usr/bin/docker-compose

usermod -aG laiye,docker laiye

# # kubectl
# HOME_DIR=`cat /etc/passwd | grep $1 | awk -F: '{print $6}'`

# install -d -m 700 -o $1 ${HOME_DIR}/.kube
# install -m 600 -o $1 /etc/kubernetes/admin.conf ${HOME_DIR}/.kube/config
