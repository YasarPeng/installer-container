#!/bin/bash

set -e

# 获取目录路径
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"

source $grandparent_path/tools/common.sh

# 设置默认参数
docker_version="${2:-24.0.9}"
docker_package="docker-${docker_version}.tgz"
docker_rootdir="${1:-/var/lib/docker}"

# 检查路径是否为绝对路径
if [[ "${docker_rootdir}" != /* ]]; then
    error "${docker_rootdir} is not an absolute path."
    exit 1
fi

# 检查系统架构
detect_system
arch="$(uname -m)"
case $arch in
    x86_64|amd64|aarch64|arm64|armv7l|armv6l|i386|i686)
        note "检测到系统架构: $arch ($ARCH)"
    ;;
    *)
        error "不支持的系统架构: $arch"
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

# get_distribution函数已在common.sh中被detect_system替代

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# 安装Docker
install_docker() {
    note "当前系统: $DISTRO $VERSION ($PKG_MANAGER)"
    
    # 创建docker组
    getent group docker > /dev/null || groupadd docker
    
    # 确保systemd目录存在
    local systemd_dir="/usr/lib/systemd/system"
    mkdir -p "$systemd_dir"
    
    # 拷贝systemd服务文件
    cp "${parent_path}/docker.service" "${systemd_dir}/docker.service"
    cp "${parent_path}/containerd.service" "${systemd_dir}/containerd.service"
    cp "${parent_path}/docker.socket" "${systemd_dir}/docker.socket"
    
    # 创建架构目录
    mkdir -p "${parent_path}/${arch}"
    
    # 安装docker二进制文件
    if [ -f "${parent_path}/${arch}/${docker_package}" ]; then
        note "使用本地Docker安装包: ${parent_path}/${arch}/${docker_package}"
        tar --strip-components=1 -xvzf "${parent_path}/${arch}/${docker_package}" -C /usr/bin
    else
        error "当前本地不存在Docker安装包, 请执行tools/download_package.sh下载Docker安装包"
        exit 1
    fi
    # 授权执行权限
    find /usr/bin -type f -name "docker" -exec chmod 755 {} \;
    
    # 配置docker daemon
    mkdir -p /etc/docker
    if [ -f "${parent_path}/daemon.json" ]; then
        sed "s#DIR#${docker_rootdir}#g" "${parent_path}/daemon.json" > /etc/docker/daemon.json
    else
        # 创建默认daemon.json
        cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "${docker_rootdir}",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "200m",
    "max-file": "3"
  },
  "default-address-pools": [
    {
      "base": "173.20.0.1/16",
      "size": 24
    }
],
  "storage-driver": "overlay2"
}
EOF
    fi
    
    # 启动docker服务
    start_service "docker"
    
    # 验证安装
    if command -v docker >/dev/null 2>&1; then
        success "Docker安装成功，版本信息:"
        docker version
    else
        error "Docker安装失败"
        exit 1
    fi
}

# 安装docker（如果未安装）
if ! command_exists dockerd; then
    install_docker
fi

# 安装docker-compose（如果未安装）
if ! command_exists docker-compose; then
    note "安装docker-compose"
    
    # 创建架构目录
    mkdir -p "${parent_path}/${arch}"
    
    if [[ -f "${parent_path}/${arch}/docker-compose" ]]; then
        note "使用本地docker-compose"
        cp "${parent_path}/${arch}/docker-compose" "/usr/bin/docker-compose"
        chmod a+x /usr/bin/docker-compose
    else
        error "当前本地不存在docker-compose安装包，请执行tools/download_package.sh下载docker-compose安装包"
        exit 1
    fi
else
    note "docker-compose已安装，跳过安装步骤"
fi
