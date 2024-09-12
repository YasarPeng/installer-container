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

# public_url="https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}"

choice_runtime() {
    underline "请选择您想要安装的容器运行时: "
    PS3=$'\033[32m输入选项编号: \033[0m'
    
    select runtime in "${!runtimes[@]}" "退出"
    do
        if [[ "$runtime" == "退出" ]]; then
            exit 0
            elif [[ -n "$runtime" ]]; then
            select version in "${runtimes[$runtime]}" "返回上一步"
            do
                if [[ "$version" == "返回上一步" ]]; then
                    choice_runtime
                elif [[ -n "$version" ]]; then
                    # download "https://download.docker.com/linux/static/stable/${arch}/docker-${version}.tgz" "${grandparent_path}/docker/${arch}/"
                    # download "https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}/docker-compose" "${grandparent_path}/docker/${arch}/"
                    downloader "$runtime" "${runtimes[$runtime]}"
                    break
                else
                    error "无效的编号选项, 请重新选择"
                fi
            done
            break
        else
            error "无效的编号选项, 请重新选择"
        fi
    done
}


downloader() {
    local service=$1
    local version=$2
    # local arch=${3:-$ARCH}
    
    case "$service" in
        "docker")
            #url="https://download.docker.com/linux/static/stable/${arch}/docker-${version}.tgz"
            #url_compose="https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}"
            url="https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}/docker-${version}.tgz"
            url_compose="https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}/docker-compose"
            wget -c ${url} -P ${grandparent_path}/docker/${arch}/
            wget -c ${url_compose} -P ${grandparent_path}/docker/${arch}/
            success "下载完成，存储路径：${grandparent_path}/docker/${arch}/"
        ;;
        "containerd")
            #url="https://github.com/containerd/nerdctl/releases/download/v1.7.6/nerdctl-full-${version}-linux-${ARCH}.tar.gz"
            url="https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}/nerdctl-full-${version}-linux-${ARCH}.tar.gz"
            wget -c ${url} -P ${grandparent_path}/containerd/${arch}/
            success "下载完成，存储路径：${grandparent_path}/containerd/${arch}/"
        ;;
    esac
}


# 定义一个关联数组，容器运行时选项
declare -A runtimes
runtimes=(
    ["docker"]="20.10.24"
    ["containerd"]="1.7.6"
)

choice_runtime
