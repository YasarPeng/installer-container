#!/bin/bash

cat <<EOF > /etc/security/limits.d/99-common.conf
* - memlock     unlimited
* - nofile      131072
* - nproc       65535
EOF

