#!/bin/bash

set -e

# Get directory path
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"

source $parent_path/common.sh

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

choice_runtime() {
    while true; do
        underline "请选择您想要安装的容器运行时: "
        PS3=$'\033[32m输入选项编号: \033[0m'
        
        local runtimes_options=("docker" "containerd")
        
        select runtime in "${runtimes_options[@]}" "退出"
        do
            if [[ "$runtime" == "退出" ]]; then
                exit 0
                elif [[ -n "$runtime" ]]; then
                case "$runtime" in
                    "docker")
                        local selected_version=$(show_version_menu "Docker" "${DOCKER_VERSIONS[@]}")
                        if [[ $? -eq 0 && -n "$selected_version" ]]; then
                            downloader "$runtime" "$selected_version"
                        else
                            # 用户选择返回主菜单，重新显示主菜单
                            break 2
                        fi
                    ;;
                    "containerd")
                        local selected_version=$(show_version_menu "containerd" "${CONTAINERD_VERSIONS[@]}")
                        if [[ $? -eq 0 && -n "$selected_version" ]]; then
                            downloader "$runtime" "$selected_version"
                        else
                            # 用户选择返回主菜单，重新显示主菜单
                            break 2
                        fi
                    ;;
                esac
                # 下载完成，退出脚本
                exit 0
            else
                error "无效的编号选项, 请重新选择"
            fi
        done
    done
}


downloader() {
    local service=$1
    local version=$2
    case "$service" in
        "docker")
            url="https://download.docker.com/linux/static/stable/${arch}/docker-${version}.tgz"
            url_rootless_extras="https://download.docker.com/linux/static/stable/${arch}/docker-rootless-extras-${version}.tgz"
            
            # 根据 Docker 版本选择兼容的 Docker Compose 版本
            local compose_version=$(get_compose_version "$version")
            url_compose="https://github.com/docker/compose/releases/download/v${compose_version}/docker-compose-linux-${arch}"
            # url="https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}/docker-${version}.tgz"
            # url_compose="https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}/docker-compose"
            wget -T 15 -c ${url} -P ${grandparent_path}/docker/${arch}/
            wget -T 15 -c ${url_rootless_extras} -P ${grandparent_path}/docker/${arch}/
            wget -T 15 -c ${url_compose} -P ${grandparent_path}/docker/${arch}/
            mv ${grandparent_path}/docker/${arch}/docker-compose-linux-${ARCH} ${grandparent_path}/docker/${arch}/docker-compose
            chmod +x ${grandparent_path}/docker/${arch}/docker-compose
            success "下载完成，存储路径：${grandparent_path}/docker/${arch}/"
        ;;
        "containerd")
            #url="https://github.com/containerd/nerdctl/releases/download/v1.7.6/nerdctl-full-${version}-linux-${ARCH}.tar.gz"
            url="https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}/nerdctl-full-${version}-linux-${ARCH}.tar.gz"
            wget -T 15 -c ${url} -P ${grandparent_path}/containerd/${arch}/
            success "下载完成，存储路径：${grandparent_path}/containerd/${arch}/"
        ;;
    esac
}

# 定义可用的版本列表
DOCKER_VERSIONS=(
    "20.10.24"
    "24.0.9"
    "26.1.4"
    "27.5.1"
)

CONTAINERD_VERSIONS=(
    "1.7.6"
    "1.7.7"
    "1.7.18"
    "1.7.20"
    "2.0.4"
    "2.0.8"
)

# 根据 Docker 版本选择兼容的 Docker Compose 版本
get_compose_version() {
    local docker_version=$1
    
    # Docker 版本与 Docker Compose 版本兼容性映射
    case "$docker_version" in
        "20.10.24")
            echo "2.20.2"  # Docker Compose v2 稳定版本
        ;;
        "24.0.9")
            echo "2.24.6"  # Docker Compose v2 最新版本
        ;;
        "26.1.4")
            echo "2.29.0"  # Docker Compose v2 最新版本
        ;;
        "27.5.1")
            echo "2.29.0"  # Docker Compose v2 最新版本
        ;;
        *)
            echo "2.29.0"  # 默认使用最新稳定版本
        ;;
    esac
}

# 显示版本选择菜单
show_version_menu() {
    local service=$1
    shift
    local versions=("$@")
    
    # 显示提示信息到 stderr，避免污染返回值
    underline "请选择 ${service} 版本: " >&2
    PS3=$'\033[32m输入版本编号: \033[0m'
    
    select version in "${versions[@]}" "返回主菜单"
    do
        if [[ "$version" == "返回主菜单" ]]; then
            return 1
            elif [[ -n "$version" ]]; then
            # 将版本输出到 stdout，确保没有其他内容污染
            printf "%s" "$version"
            return 0
        else
            error "无效的编号选项, 请重新选择" >&2
        fi
    done
}

choice_runtime
