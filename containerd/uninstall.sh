#!/bin/bash

set -e

# Get directory path
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"

source $grandparent_path/tools/common.sh

#Get cpu arch
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

containerd_rootdir="${1:-/data/laiye/containerd}"
containerd_version="1.7.6"
containerd_package="nerdctl-full-${containerd_version}-linux-${ARCH}.tar.gz"

# 停止 containerd 和 buildkit 服务
services=("containerd" "buildkit")
for service in ${services[@]}; do
    if systemctl is-active --quiet "$service"; then
        success "停止 ${service} 服务"
        systemctl stop "$service"
        systemctl daemon-reload
    else
        note "${service} 服务已停止，无需操作"
    fi
done

# 删除 containerd 数据目录
if [[ -d "${containerd_rootdir}" ]]; then
    info "删除 ${containerd_rootdir} 数据目录..."
    rm -rf "${containerd_rootdir}" && success "删除完成 ${containerd_rootdir} 数据目录..."
else
    warn "${containerd_rootdir} 目录不存在，无需删除。"
fi

# 删除各个相关文件
files=$(tar tf ${parent_path}/${arch}/${containerd_package}|grep -v "/$")
for filepath in ${files[@]}; do
    if [[ -f "/usr/local/${filepath}" ]]; then
        success "删除 /usr/local/${filepath}..."
        rm -f "/usr/local/${filepath}"
    else
        warn "/usr/local/${filepath} 文件不存在，无需删除。"
    fi
done

success "所有指定的 containerd 相关数据和服务已删除。"

