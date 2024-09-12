#!/bin/bash

set -e

# 初始化函数
parent_path="$(cd "$(dirname "$0")" && pwd)"
source "$parent_path/tools/common.sh"

# 卸载容器运行时的函数
uninstall_runtime() {
    local choice=$1
    local rootdir=$2
    
    case "$choice" in
        dockerd|d)
            bash "$parent_path/docker/uninstall.sh" "$rootdir"
        ;;
        containerd|c)
            bash "$parent_path/containerd/uninstall.sh" "$rootdir"
        ;;
    esac
}

# 显示容器运行时选项
choice_runtime() {
    underline "请选择您想要卸载的容器运行时: "
    PS3=$'\033[32m输入选项编号: \033[0m'
    
    select runtime in "${!runtimes[@]}" "退出"
    do
        if [[ "$runtime" == "退出" ]]; then
            exit 0
            elif [[ -n "$runtime" ]]; then
            choice_rootdir "$runtime" "${runtimes[$runtime]}"
            break
        else
            error "无效的编号选项, 请重新选择"
        fi
    done
}

choice_rootdir() {
    local service=$1
    local default_dir=$2
    local rootdir="$default_dir"
    
    while true; do
        warn "你当前选择卸载的服务是$service, 其默认数据存储路径为:${rootdir}。"
        warn "(注意: 该操作将会删除所有${service}容器数据包括${rootdir}目录并卸载${service}服务,请谨慎操作!)"
        underline "请确认是否继续卸载删除: "
        PS3=$'\033[32m输入选项编号: \033[0m'
        
        local options=("继续" "变更路径" "返回上一步")
        
        select opt in "${options[@]}" "退出"
        do
            case "$opt" in
                "继续")
                    uninstall_runtime "$service" "$rootdir"
                    return
                ;;
                "变更路径")
                    read -p "请输入您要变更的存储路径: " rootdir
                    break
                ;;
                "返回上一步")
                    choice_runtime
                ;;
                "退出")
                    exit 0
                ;;
                *)
                    error "无效的编号选项, 请重新选择"
                ;;
            esac
        done
    done
}

# 定义一个关联数组，容器运行时选项
declare -A runtimes
runtimes=(
    ["dockerd"]="/data/laiye/dockerd"
    ["containerd"]="/data/laiye/containerd"
)

# 选择容器运行时
choice_runtime

