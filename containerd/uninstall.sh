#!/bin/bash

#set -e

# Get directory path
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"
containerd_package="nerdctl-full-1.7.6.tar.gz"
containerd_rootdir="${1:-/data/laiye}/containerd"

source $grandparent_path/tools/common.sh

# Get cpu arch
arch=`/usr/bin/uname -m`
if [[ $arch != "x86_64" && $arch != "aarch64" ]]; then
    error "The current hardware platform or virtual platform is not supported."
    exit -1
fi

read -p "当前操作会完全删除所有Containerd容器数据并卸载containerd服务,请确认是否继续(y/n)? " choice

delete_file() {
    local filepath=$1
    note "删除 ${filepath}"
    if [[ -e "$filepath" ]]; then
        rm -f "$filepath"
    else
        warn "${filepath} 不存在，无需删除"
    fi
}

case "$choice" in
    [yY][eE][sS]|[yY])
        services=("containerd" "buildkit")
        files=$(tar tf ${parent_path}/${arch}/${containerd_package}|grep -v "/$")
        
        # 停止 containerd 和 containerd 服务
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
            success "删除 ${containerd_rootdir} 数据目录..."
            rm -rf "${containerd_rootdir}"
        else
            warn "${containerd_rootdir} 目录不存在，无需删除。"
        fi
        
        # 删除各个相关文件
        for filepath in ${files[@]}; do
            delete_file "/usr/local/${filepath}"
        done
        success "所有指定的 containerd 相关数据和服务已删除。"
    ;;
    [nN][oO]|[nN])
        note "操作已取消。"
    ;;
    *)
        warn "无效输入，请输入 'y' 或 'n'。"
    ;;
esac
