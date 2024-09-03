#!/bin/bash

set -e

# Get directory path
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"
docker_rootdir="${1:-/data/laiye}/Docker"

source $grandparent_path/tools/common.sh

read -p "当前操作会完全删除所有Docker容器数据并卸载docker服务, 请确认是否继续? (y/n): " choice

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
        services=("docker" "containerd")
        files=(
            "/usr/lib/systemd/system/docker.service"
            "/usr/lib/systemd/system/containerd.service"
            "/etc/docker/daemon.json"
            "/usr/lib/systemd/system/docker.socket"
            "/usr/bin/docker-compose"
            "/usr/bin/docker"
            "/usr/bin/dockerd"
            "/usr/bin/docker-proxy"
            "/usr/bin/docker-init"
            "/usr/bin/containerd-shim-runc-v2"
            "/usr/bin/ctr"
            "/usr/bin/runc"
            "/usr/bin/containerd"
            "/usr/bin/containerd-shim" 
        )

        # 停止 Docker 和 containerd 服务
        for service in "${services[@]}"; do
            if systemctl is-active --quiet "$service"; then
                success "停止 ${service} 服务"
                systemctl stop "$service"
                systemctl daemon-reload
            else
                note "${service} 服务已停止，无需操作。"
            fi
        done

        # 删除 Docker 数据目录
        if [[ -d "${docker_rootdir}" ]]; then
            success "删除 ${docker_rootdir} 数据目录"
            rm -rf "${docker_rootdir}"
        else
            warn "${docker_rootdir} 目录不存在，无需删除"
        fi

        # 删除各个相关文件
        for filepath in "${files[@]}"; do
            delete_file "$filepath"
        done
        success "所有指定的 Docker 相关数据和服务已删除"
        ;;
    [nN][oO]|[nN])
        note "操作已取消。"
        ;;
    *)
        warn "无效输入，请输入 'y' 或 'n'"
        ;;
esac
