#!/bin/bash

set -e

# 获取目录路径
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"
source "$grandparent_path/tools/common.sh"

# 检查系统架构
detect_system
arch="$(uname -m)"
note "检测到系统架构: $arch ($ARCH)"

# 验证架构是否被containerd/nerdctl支持
case $ARCH in
    amd64|arm64|armv7l|386)
        note "架构 $ARCH 支持安装containerd"
        ;;
    *)
        error "containerd/nerdctl 不支持当前架构: $ARCH"
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
if [[ ! -f "${parent_path}/${arch}/${containerd_package}" ]]; then
    mkdir -p "${parent_path}/${arch}"
    note "本地未找到 ${containerd_package}，正在从网络下载..."

    # 尝试多个下载源
    local download_urls=(
        "https://github.com/containerd/nerdctl/releases/download/v${containerd_version}/${containerd_package}"
        "https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}/${containerd_package}"
    )

    local download_success=false

    for url in "${download_urls[@]}"; do
        note "尝试从 ${url} 下载..."

        if command -v wget &>/dev/null && wget -c -O "${parent_path}/${arch}/${containerd_package}" "$url"; then
            download_success=true
            break
        elif command -v curl &>/dev/null && curl -L -o "${parent_path}/${arch}/${containerd_package}" "$url"; then
            download_success=true
            break
        fi

        warn "从 $url 下载失败，尝试下一个源..."
    done

    if [ "$download_success" = false ]; then
        error "所有下载源都失败，请手动下载 ${containerd_package} 到 ${parent_path}/${arch}/"
        exit 1
    fi

    success "下载完成：${parent_path}/${arch}/${containerd_package}"
fi

# 安装 containerd
note "正在安装 containerd..."
tar -C /usr/local -xvzf "${parent_path}/${arch}/${containerd_package}"

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
note "启动 containerd 相关服务..."
start_service "containerd"

# 尝试启动buildkit服务（如果存在）
if systemctl list-unit-files | grep -q "buildkit.service"; then
    start_service "buildkit"
else
    warn "buildkit服务未找到，跳过启动"
fi

# 验证安装
if command -v nerdctl >/dev/null 2>&1; then
    success "containerd 安装完成，版本信息如下："
    nerdctl version
    nerdctl info
else
    error "nerdctl安装失败或不可用"
    exit 1
fi