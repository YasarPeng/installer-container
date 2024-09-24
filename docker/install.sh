#!/bin/bash

set -e

# Get directory path
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"

docker_version="20.10.24"
docker_package="docker-${docker_version}.tgz"
docker_rootdir="${1:-/var/lib/docker}"

if [[ "${docker_rootdir}" != /* ]]; then
    error "${docker_rootdir} is not an absolute path."
    exit 1
fi

source $grandparent_path/tools/common.sh


# Get cpu arch
arch=`/usr/bin/uname -m`
if [[ $arch != "x86_64" && $arch != "aarch64" ]]; then
    error "The current hardware platform or virtual platform is not supported."
    exit -1
fi

# Check podman
which podman &> /dev/null && error "Podman is installed, uninstall it first.
    If you are using the 'yum' package manager, Use: yum remove -y podman
    If you are using the 'apt' package manager, Use: apt remove -y podman
" && exit -1

# Check docker
which dockerd &> /dev/null && error "Dockerd is installed, uninstall it first.
    If you are using the 'yum' package manager, Use: yum remove -y docker
    If you are using the 'apt' package manager, Use: apt remove -y docker
" && exit -1

# Get a Linux distribution
get_distribution() {
    lsb_dist=""
    if [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
    fi
    note "$lsb_dist"
}

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# 安装Docker
install_docker() {
    lsb_dist=$(get_distribution)
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    note "Current system is $lsb_dist"
    
    # 创建docker组（如果不存在）
    egrep "^docker" /etc/group >& /dev/null || groupadd docker
    
    # 拷贝相关文件
    cp "${parent_path}/docker.service" "/usr/lib/systemd/system/docker.service"
    cp "${parent_path}/containerd.service" "/usr/lib/systemd/system/containerd.service"
    cp "${parent_path}/docker.socket" "/usr/lib/systemd/system/docker.socket"
    
    # 解压安装docker二进制文件
    tar --strip-components=1 -xvzf ${parent_path}/${arch}/${docker_package} -C /usr/bin
    mkdir -p /etc/docker
    
    # 设置docker的daemon配置文件
    sed  "s#DIR#${docker_rootdir}#g" "${parent_path}/daemon.json" > /tmp/daemon.json
    [ -f /etc/docker/daemon.json ] || cp /tmp/daemon.json /etc/docker/daemon.json
    
    # 启用并启动docker服务
    systemctl daemon-reload
    systemctl enable --now docker
    
    # 设置相关文件的权限
    chmod -R u+x,g+x /usr/bin
    
    # 输出docker状态
    docker version
}

if ! command_exists dockerd; then
    install_docker
fi

if ! command_exists docker-compose; then
    cp "${parent_path}/${arch}/docker-compose" "/usr/bin/docker-compose"
    chmod a+x /usr/bin/docker-compose
fi