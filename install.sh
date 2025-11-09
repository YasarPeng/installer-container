#!/bin/bash

set -e

# 初始化函数
parent_path="$(cd "$(dirname "$0")" && pwd)"
source "$parent_path/tools/common.sh"

initialize() {
    # 系统检测和初始化
    h1 "系统兼容性检查"
    detect_system
    note "检测到的系统信息:"
    note "  架构: $ARCH"
    note "  发行版: $DISTRO $VERSION"
    note "  包管理器: $PKG_MANAGER"
    
    # 检查必要工具
    # check_dependencies
    
    # 测试网络连接
    # test_network || warn "网络连接可能存在问题，继续安装但可能需要手动下载"
    
    # 执行系统初始化脚本
    h1 "系统初始化配置"
    bash "$parent_path/tools/config_limits.sh"
    bash "$parent_path/tools/disable_swap.sh"
    bash "$parent_path/tools/enable_br_netfilter.sh"
    bash "$parent_path/tools/enable_ipv4_forward.sh"
    bash "$parent_path/tools/enable_ipvs.sh"
    bash "$parent_path/tools/disable_firewall.sh" || true
}

# 安装容器运行时的函数
install_runtime() {
    local choice="$1"
    local rootdir="$2"
    local version="$3"
    
    case "$choice" in
        dockerd)
            bash "$parent_path/docker/install.sh" "$rootdir" "$version"
        ;;
        containerd)
            bash "$parent_path/containerd/install.sh" "$rootdir" "$version"
        ;;
    esac
    
    # 安装完成后询问是否授权普通用户
    note "安装完成，如果需要授权普通用户请执行脚本: $parent_path/tools/authorize_user.sh"
    # post_install_authorization "$choice"
}

# 安装后授权
post_install_authorization() {
    local runtime="$1"
    
    echo
    h2 "用户权限配置"
    
    PS3=$'\033[32m请选择用户权限配置方式: \033[0m'
    local auth_options=(
        "授权当前用户"
        "授权指定用户"
        "授权所有普通用户"
        "跳过用户授权"
        "列出已授权用户"
    )
    
    select auth_choice in "${auth_options[@]}"; do
        case "$auth_choice" in
            "授权当前用户")
                local current_user="${SUDO_USER:-$(logname 2>/dev/null)}"
                if [ -n "$current_user" ]; then
                    note "为当前用户 $current_user 授权..."
                    sudo bash "$parent_path/tools/authorize_user.sh" -u "$current_user"
                else
                    error "无法确定当前用户"
                fi
                break
            ;;
            "授权指定用户")
                read -r -p "请输入要授权的用户名: " target_user
                if [ -n "$target_user" ]; then
                    sudo bash "$parent_path/tools/authorize_user.sh" -u "$target_user"
                else
                    error "用户名不能为空"
                fi
                break
            ;;
            "授权所有普通用户")
                sudo bash "$parent_path/tools/authorize_user.sh" -a
                break
            ;;
            "跳过用户授权")
                note "跳过用户授权，您可以稍后手动运行:"
                note "  sudo bash tools/authorize_user.sh"
                break
            ;;
            "列出已授权用户")
                sudo bash "$parent_path/tools/authorize_user.sh" -l
                echo
                note "请重新选择操作:"
            ;;
            *)
                echo "无效的选项，请重新选择！"
            ;;
        esac
    done
}

# 定义容器运行时选项
declare -A runtimes=(
    ["dockerd"]="/data/laiye/dockerd"
    ["containerd"]="/data/laiye/containerd"
)

# 定义容器版本
declare -a dockerd_versions=("19.03.15" "20.10.24" "24.0.9" "25.0.5" "26.1.4")
declare -a containerd_versions=("1.7.6" "1.7.7" "2.0.0" "2.0.2" "2.0.3")

# 选择容器运行时
choice_runtime() {
    underline "请选择您想要安装的容器运行时:"
    PS3=$'\033[32m输入选项编号: \033[0m'
    
    select runtime in "${!runtimes[@]}" "退出"; do
        if [[ "$runtime" == "退出" ]]; then
            exit 0
            elif [[ -n "$runtime" ]]; then
            choice_rootdir "$runtime" "${runtimes[$runtime]}"
            break
        else
            echo "无效的选项，请重新选择！"
        fi
    done
}

# 选择版本
choice_version() {
    local service="$1"
    local versions
    
    if [[ "$service" == "dockerd" ]]; then
        versions=("${dockerd_versions[@]}")
    else
        versions=("${containerd_versions[@]}")
    fi
    
    underline "请选择 $service 的版本:"
    PS3=$'\033[32m输入选项编号: \033[0m'
    
    select version in "${versions[@]}" "返回上一步" "退出"; do
        case "$version" in
            "退出") exit 0 ;;
            "返回上一步") choice_runtime ;;
            *) return ;;
        esac
    done
}

# 选择存储路径
choice_rootdir() {
    local service="$1"
    local rootdir="$2"
    
    while true; do
        note "当前选择的运行时: $service"
        note "默认存储路径: $rootdir"
        underline "请确认是否继续安装: "
        
        PS3=$'\033[32m输入选项编号: \033[0m'
        local options=("继续" "变更路径" "返回上一步" "退出")
        
        select opt in "${options[@]}"; do
            case "$opt" in
                "继续")
                    # choice_version "$service" 是否开启版本选择
                    install_runtime "$service" "$rootdir" "$version"
                    return
                ;;
                "变更路径")
                    read -r -p "请输入新的存储路径: " rootdir
                    break
                ;;
                "返回上一步") choice_runtime ;;
                "退出") exit 0 ;;
                *) echo "无效的选项，请重新选择！" ;;
            esac
        done
    done
}

# 初始化环境
initialize

# 选择容器运行时
choice_runtime
