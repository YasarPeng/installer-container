#!/bin/bash

set -e

# 初始化函数
initialize() {
    bash tools/config_limits.sh
    bash tools/disable_swap.sh
    bash tools/enable_br_netfilter.sh
    bash tools/enable_ipv4_forward.sh
    bash tools/enable_ipvs.sh
    bash tools/disable_firewall.sh || true
    #bash tools/firewall.sh || true
}

# 安装容器运行时的函数
install_runtime() {
    local choice=$1
    local rootdir=$2
    
    case "$choice" in
        dockerd|d)
            cd docker && bash install.sh "$rootdir" && cd ..
        ;;
        containerd|c)
            cd containerd && bash install.sh "$rootdir" && cd ..
        ;;
        *)
            echo "无效输入, 请输入 'dockerd' 或 'containerd'"
            exit 1
        ;;
    esac
}

# 初始化容器环境
initialize

# 获取用户输入
read -p "请输入你想要安装的容器运行时 (dockerd|containerd): " choice
choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')  # 转换为小写

# 验证用户输入
if [[ "$choice" != "dockerd" && "$choice" != "containerd" ]]; then
    echo "无效输入, 请输入 'docker' 或 'containerd'"
    exit 1
fi

# 获取存储目录
read -p "请输入 ${choice} 容器运行时用于存储其所有数据的目录 (默认目录路径为: /data/laiye): " rootdir
rootdir=${rootdir:-/data/laiye}  # 如果未输入，使用默认值

# 安装指定的容器运行时
install_runtime "$choice" "$rootdir"
