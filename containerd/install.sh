#!/bin/bash

set -e

# Get directory path
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"
containerd_package="nerdctl-full-1.7.6.tar.gz"
containerd_rootdir="${1:-/data/laiye}/containerd"

# Get cpu arch
arch=`/usr/bin/uname -m`
if [[ $arch != "x86_64" && $arch != "aarch64" ]]; then
    error "The current hardware platform or virtual platform is not supported."
    exit -1
fi

# check dockerd
which dockerd && echo "ERROR: dockerd is installed, uninstall it first." && exit -1

# check podman
which podman && echo "ERROR: podman is installed, uninstall it first." && exit -1

# install
tar Cxzvf /usr/local ${parent_path}/${arch}/${containerd_package}

# config
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i '/sandbox_image/ s#registry.k8s.io/pause:3.8#localhost:5000/registry.aliyuncs.com/google_containers/pause:3.8#g' /etc/containerd/config.toml
sed -i '/SystemdCgroup/ s#false#true#g' /etc/containerd/config.toml
sed -i '/disable_apparmor/ s#false#true#g' /etc/containerd/config.toml
sed -i "/^root/ s#/var/lib/containerd#${containerd_rootdir}#g" /etc/containerd/config.toml

systemctl daemon-reload
systemctl enable --now containerd
systemctl enable --now buildkit.service
# systemctl enable --now stargz-snapshotter.service

nerdctl version