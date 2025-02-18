#!/bin/bash

set -e

# 获取目录路径
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"
source $grandparent_path/tools/common.sh

# 设置默认参数
docker_version="${2:-20.10.24}"
docker_package="docker-${docker_version}.tgz"
docker_rootdir="${1:-/var/lib/docker}"

# 检查路径是否为绝对路径
if [[ "${docker_rootdir}" != /* ]]; then
    error "${docker_rootdir} is not an absolute path."
    exit 1
fi

# 检查系统架构
arch="$(uname -m)"
case $arch in
    x86_64|aarch64)
    ;;
    *)
        error "The current hardware platform or virtual platform is not supported."
        exit 1
    ;;
esac

# 检查容器运行时冲突
if which podman &> /dev/null; then
    error "Podman is installed, please uninstall it first:
    - For yum: yum remove -y podman
    - For apt: apt remove -y podman"
    exit 1
fi

if which dockerd &> /dev/null; then
    error "Dockerd is installed, please uninstall it first:
    - For yum: yum remove -y docker
    - For apt: apt remove -y docker"
    exit 1
fi

# 获取Linux发行版
get_distribution() {
    if [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
        echo "${lsb_dist,,}"  # 转换为小写
    fi
}

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# 安装Docker
install_docker() {
    local lsb_dist=$(get_distribution)
    note "Current system is $lsb_dist"
    
    # 创建docker组
    getent group docker > /dev/null || groupadd docker
    
    # 拷贝systemd服务文件
    local systemd_dir="/usr/lib/systemd/system"
    cp "${parent_path}/docker.service" "${systemd_dir}/docker.service"
    cp "${parent_path}/containerd.service" "${systemd_dir}/containerd.service"
    cp "${parent_path}/docker.socket" "${systemd_dir}/docker.socket"
    
    # 安装docker二进制文件
    if [ -f "${parent_path}/${arch}/${docker_package}" ]; then
        note "使用本地Docker安装包"
        tar --strip-components=1 -xvzf "${parent_path}/${arch}/${docker_package}" -C /usr/bin
    else
        note "从Docker官方下载安装包"
        wget -c "https://download.docker.com/linux/static/stable/${arch}/docker-${docker_version}.tgz" -O "${parent_path}/${arch}/docker-${docker_version}.tgz"
        tar --strip-components=1 -xvzf "${parent_path}/${arch}/docker-${docker_version}.tgz" -C /usr/bin
    fi
    chmod -R u+x,g+x /usr/bin
    
    # 配置docker daemon
    mkdir -p /etc/docker
    sed "s#DIR#${docker_rootdir}#g" "${parent_path}/daemon.json" > /etc/docker/daemon.json
    
    # 启动docker服务
    systemctl daemon-reload
    systemctl enable --now docker
    
    # 验证安装
    docker version
}

# 安装docker（如果未安装）
if ! command_exists dockerd; then
    install_docker
fi

# 安装docker-compose（如果未安装）
if ! command_exists docker-compose; then
    if [[ -f "${parent_path}/${arch}/docker-compose" ]]; then
        cp "${parent_path}/${arch}/docker-compose" "/usr/bin/docker-compose"
        chmod a+x /usr/bin/docker-compose
    else
        echo "本地未找到 docker-compose，尝试从网络下载..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o "${parent_path}/${arch}/docker-compose"
        cp "${parent_path}/${arch}/docker-compose" "/usr/bin/docker-compose"
        chmod a+x /usr/bin/docker-compose
    fi
else
    echo "docker-compose 已安装，跳过安装步骤。"
fi
