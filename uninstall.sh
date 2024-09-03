#!/bin/bash

set -e

# 安装容器运行时的函数
uninstall_runtime() {
    local choice=$1
    local rootdir=$2
    
    case "$choice" in
        dockerd|d)
            cd docker && bash uninstall.sh "$rootdir" && cd ..
        ;;
        containerd|c)
            cd containerd && bash uninstall.sh "$rootdir" && cd ..
        ;;
        *)
            echo "无效输入, 请输入 'dockerd' 或 'containerd'"
            exit 1
        ;;
    esac
}

# 获取用户输入
read -p "请输入你想要卸载的容器运行时 (dockerd|containerd): " choice
choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')  # 转换为小写

# 验证用户输入
if [[ "$choice" != "dockerd" && "$choice" != "containerd" ]]; then
    echo "无效输入, 请输入 'dockerd' 或 'containerd'"
    exit 1
fi

# 获取存储目录
read -p "请输入 ${choice} 容器运行时用于存储其所有数据的目录 (默认目录路径为: /data/laiye): " rootdir
rootdir=${rootdir:-/data/laiye}  # 如果未输入，使用默认值

# 安装指定的容器运行时
uninstall_runtime "$choice" "$rootdir"