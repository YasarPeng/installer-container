#!/bin/bash

set -e

# Get directory path
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"

source $parent_path/common.sh

# Get cpu arch
if [ -z "$1" ]; then
    arch="x86_64"
    elif [ "$1" == "aarch64" ]; then
    arch="aarch64"
else
    error "未指定CPU类型"
    exit -1
fi

public_url="https://private-deploy.oss-cn-beijing.aliyuncs.com/pengyongshi/images/${arch}"

read -p "请输入你想要安装的容器运行时(dockerd|containerd): " choice

case "$choice" in
    [dD][oO][cC][kK][eE][rR][dD]|[dD])
        # docker
        docker="docker-20.10.24.tgz"
        docker_compose="docker-compose"
        wget -c ${public_url}/${docker} -P ${grandparent_path}/docker/${arch}/
        wget -c ${public_url}/${docker_compose} -P ${grandparent_path}/docker/${arch}/
    ;;
    [cC][oO][nN][tT][aA][iI][nN][eE][rR][dD]|[cC])
        nerdctl_full="nerdctl-full-1.7.6.tar.gz"
        wget -c ${public_url}/${nerdctl_full} -P ${grandparent_path}/containerd/${arch}/
    ;;
    *)
        warn "无效输入,请输入'docker' 或 'containerd'"
    ;;
esac


