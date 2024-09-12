#!/bin/bash

set -e

# Check architecture
arch="$(uname -m)"
case $arch in
    x86_64)
        ARCH="amd64"
    ;;
    aarch64)
        ARCH="arm64"
    ;;
    *)
        error "The current hardware platform or virtual platform is not supported."
        exit 1
    ;;
esac

# Get directory path
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"
containerd_rootdir="${1:-/data/laiye/containerd}"
containerd_version="1.7.6"
containerd_package="nerdctl-full-${containerd_version}-linux-${ARCH}.tar.gz"

# Check for conflicts with other container runtimes
if which dockerd &> /dev/null || which podman &> /dev/null; then
    error "Please uninstall dockerd or podman first."
    exit 1
fi

# Install
tar Cxzvf /usr/local "${parent_path}/${arch}/${containerd_package}"

# Configure
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i -e '/sandbox_image/ s#registry.k8s.io/pause:3.8#localhost:5000/registry.aliyuncs.com/google_containers/pause:3.8#g' \
-e '/SystemdCgroup/ s#false#true#g' \
-e '/disable_apparmor/ s#false#true#g' \
-e "/^root/ s#/var/lib/containerd#${containerd_rootdir}#g" \
/etc/containerd/config.toml

# Enable and start services
systemctl daemon-reload
systemctl enable --now containerd
systemctl enable --now buildkit.service
# systemctl enable --now stargz-snapshotter.service

nerdctl version

