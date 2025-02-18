#!/bin/bash

set -e

# 获取目录路径
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"
source "$grandparent_path/tools/common.sh"

# 检查系统架构
arch="$(uname -m)"
case $arch in
    x86_64|aarch64)
        ARCH="${arch/x86_64/amd64}"
        ARCH="${ARCH/aarch64/arm64}"
    ;;
    *)
        error "The current hardware platform or virtual platform is not supported."
        exit 1
    ;;
esac

# 设置默认参数
containerd_version="${2:-1.7.6}"
containerd_rootdir="${1:-/data/laiye/containerd}"
containerd_package="nerdctl-full-${containerd_version}-linux-${ARCH}.tar.gz"
containerd_url="https://github.com/containerd/nerdctl/releases/download/v${containerd_version}/${containerd_package}"

# 检查路径是否为绝对路径
if [[ "${containerd_rootdir}" != /* ]]; then
    error "${containerd_rootdir} is not an absolute path."
    exit 1
fi

# 检查容器运行时冲突
if which dockerd &> /dev/null || which podman &> /dev/null; then
    error "Please uninstall dockerd or podman first:
    - For yum: yum remove -y docker podman
    - For apt: apt remove -y docker podman"
    exit 1
fi

# 下载 nerdctl 包（如果本地不存在）
if [[ ! -f "${parent_path}/${ARCH}/${containerd_package}" ]]; then
    mkdir -p "${parent_path}/${ARCH}"
    note "本地未找到 ${containerd_package}，正在从网络下载..."
    
    if command -v wget &>/dev/null; then
        wget -O "${parent_path}/${ARCH}/${containerd_package}" "${containerd_url}"
        elif command -v curl &>/dev/null; then
        curl -L -o "${parent_path}/${ARCH}/${containerd_package}" "${containerd_url}"
    else
        error "未找到 wget 或 curl，无法下载 nerdctl。请手动下载到 ${parent_path}/${ARCH}/"
        exit 1
    fi
    
    note "下载完成：${parent_path}/${ARCH}/${containerd_package}"
fi

# 安装 containerd
note "正在安装 containerd..."
tar -C /usr/local -xvzf "${parent_path}/${ARCH}/${containerd_package}"

# 配置 containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# 修改配置文件
sed -i \
-e '/sandbox_image/ s#registry.k8s.io/pause:3.8#localhost:5000/registry.aliyuncs.com/google_containers/pause:3.8#g' \
-e '/SystemdCgroup/ s#false#true#g' \
-e '/disable_apparmor/ s#false#true#g' \
-e "/^root/ s#/var/lib/containerd#${containerd_rootdir}#g" \
/etc/containerd/config.toml

# 启动服务
note "启动 containerd 服务..."
systemctl daemon-reload
systemctl enable --now containerd
systemctl enable --now buildkit.service

# 验证安装
note "containerd 安装完成，版本信息如下："
nerdctl version