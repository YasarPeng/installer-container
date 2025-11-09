#!/bin/bash

# 普通用户运维授权脚本
# 为指定用户添加Docker和Containerd管理权限

set -e

# 获取脚本目录
parent_path="$(cd "$(dirname "$0")" && pwd)"
source "$parent_path/common.sh"

h1 "普通用户运维授权工具"

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] [用户名]

选项:
    -u, --user USER     指定要授权的用户名 (默认为当前用户)
    -g, --group GROUP   指定用户组 (默认为docker)
    -r, --revoke        撤销用户权限
    -l, --list          列出当前已授权用户
    -a, --all           为所有现有用户授权
    -h, --help          显示此帮助信息

示例:
    $0                           # 为当前用户授权
    $0 -u username               # 为指定用户授权
    $0 -u username -r            # 撤销指定用户权限
    $0 -l                        # 列出已授权用户
    $0 -a                        # 为所有用户授权
EOF
}

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

# 检查是否以root权限运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "此脚本需要root权限运行"
        note "请使用: sudo $0 $*"
        exit 1
    fi
}

# 检测系统类型
detect_system() {
    source "$parent_path/common.sh"
    detect_system
}

# 创建Docker用户组
create_docker_group() {
    if ! getent group docker >/dev/null 2>&1; then
        note "创建docker用户组..."
        groupadd docker
        success "docker用户组创建成功"
    else
        success "docker用户组已存在"
    fi
}

# 为用户授权Docker权限
authorize_docker_user() {
    local username="$1"

    # 检查用户是否存在
    if ! id "$username" >/dev/null 2>&1; then
        error "用户 $username 不存在"
        return 1
    fi

    # 创建docker组
    create_docker_group

    # 将用户添加到docker组
    if id -nG "$username" | grep -qw docker; then
        note "用户 $username 已在docker组中"
    else
        note "将用户 $username 添加到docker组..."
        usermod -aG docker "$username"
        success "用户 $username 已添加到docker组"
    fi

    # 设置权限
    setup_docker_permissions "$username"

    # 设置sudo免密权限
    setup_sudo_nopasswd "$username"
}

# 设置Docker相关权限
setup_docker_permissions() {
    local username="$1"

    note "设置Docker相关目录权限..."

    # Docker相关目录权限
    local docker_dirs=(
        "/var/run/docker.sock"
        "/var/lib/docker"
        "/etc/docker"
        "/usr/bin/docker*"
        "/usr/local/bin/docker*"
    )

    for dir_pattern in "${docker_dirs[@]}"; do
        if ls $dir_pattern >/dev/null 2>&1; then
            chown -R root:docker $dir_pattern 2>/dev/null || true
            chmod -R g+rw $dir_pattern 2>/dev/null || true
        fi
    done

    # Containerd相关权限
    local containerd_dirs=(
        "/var/run/containerd"
        "/var/lib/containerd"
        "/etc/containerd"
        "/usr/local/bin/containerd*"
        "/usr/local/bin/nerdctl*"
        "/usr/local/bin/buildkit*"
    )

    for dir_pattern in "${containerd_dirs[@]}"; do
        if ls $dir_pattern >/dev/null 2>&1; then
            chown -R root:docker $dir_pattern 2>/dev/null || true
            chmod -R g+rw $dir_pattern 2>/dev/null || true
        fi
    done

    success "Docker权限设置完成"
}

# 设置sudo免密权限
setup_sudo_nopasswd() {
    local username="$1"

    note "设置sudo免密权限..."

    local sudo_file="/etc/sudoers.d/docker-users"

    # 创建sudoers文件
    cat > "$sudo_file" << EOF
# Docker用户免密权限配置
# 由installer-container自动生成
$username ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/dockerd, /usr/bin/docker-compose
$username ALL=(ALL) NOPASSWD: /usr/local/bin/nerdctl, /usr/local/bin/containerd, /usr/local/bin/buildkit*
$username ALL=(ALL) NOPASSWD: /bin/systemctl start docker, /bin/systemctl stop docker, /bin/systemctl restart docker
$username ALL=(ALL) NOPASSWD: /bin/systemctl start containerd, /bin/systemctl stop containerd, /bin/systemctl restart containerd
$username ALL=(ALL) NOPASSWD: /bin/systemctl status docker, /bin/systemctl status containerd
$username ALL=(ALL) NOPASSWD: /bin/systemctl enable docker, /bin/systemctl disable docker
$username ALL=(ALL) NOPASSWD: /bin/systemctl enable containerd, /bin/systemctl disable containerd
EOF

    # 设置文件权限
    chmod 440 "$sudo_file"

    success "sudo免密权限设置完成"
}

# 撤销用户权限
revoke_user_permissions() {
    local username="$1"

    # 检查用户是否存在
    if ! id "$username" >/dev/null 2>&1; then
        error "用户 $username 不存在"
        return 1
    fi

    note "撤销用户 $username 的Docker权限..."

    # 从docker组中移除用户
    if id -nG "$username" | grep -qw docker; then
        gpasswd -d "$username" docker
        success "已从docker组中移除用户 $username"
    else
        note "用户 $username 不在docker组中"
    fi

    # 删除sudo免密配置
    local sudo_file="/etc/sudoers.d/docker-users"
    if [ -f "$sudo_file" ]; then
        sed -i "/^$username ALL/d" "$sudo_file" 2>/dev/null || true
        # 如果文件为空则删除
        if [ ! -s "$sudo_file" ]; then
            rm -f "$sudo_file"
        fi
        success "已删除sudo免密配置"
    fi
}

# 列出已授权用户
list_authorized_users() {
    h2 "当前已授权Docker权限的用户"

    if getent group docker >/dev/null 2>&1; then
        note "Docker组成员:"
        getent group docker | cut -d: -f4 | tr ',' '\n' | sed '/^$/d' | while read user; do
            if [ -n "$user" ]; then
                echo "  - $user"
            fi
        done
    else
        warn "docker组不存在"
    fi

    echo
    note "具有sudo免密权限的用户:"
    local sudo_file="/etc/sudoers.d/docker-users"
    if [ -f "$sudo_file" ]; then
        grep -v "^#" "$sudo_file" | grep -v "^$" | cut -d' ' -f1 | sort -u | while read user; do
            if [ -n "$user" ]; then
                echo "  - $user"
            fi
        done
    else
        note "无sudo免密配置文件"
    fi
}

# 为所有用户授权
authorize_all_users() {
    note "为所有系统用户授权Docker权限..."

    # 获取所有普通用户 (UID >= 1000)
    local users=()
    while IFS=: read -r username _ uid _ _ _ _; do
        if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
            users+=("$username")
        fi
    done < /etc/passwd

    if [ ${#users[@]} -eq 0 ]; then
        warn "未找到普通用户"
        return 1
    fi

    note "找到 ${#users[@]} 个普通用户，正在授权..."

    for user in "${users[@]}"; do
        note "授权用户: $user"
        authorize_docker_user "$user"
    done

    success "所有用户授权完成"
}

# 验证用户权限
verify_permissions() {
    local username="$1"

    h2 "验证用户权限"

    note "检查用户 $username 的权限..."

    # 检查用户是否在docker组中
    if id -nG "$username" | grep -qw docker; then
        success "✓ 用户在docker组中"
    else
        warn "✗ 用户不在docker组中"
    fi

    # 检查sudo配置
    if sudo -l -U "$username" 2>/dev/null | grep -q "docker\|containerd"; then
        success "✓ 用户具有sudo免密权限"
    else
        warn "✗ 用户无sudo免密权限"
    fi

    # 尝试测试Docker命令 (如果Docker已安装)
    if command -v docker >/dev/null 2>&1; then
        note "测试Docker命令访问..."
        if sudo -u "$username" docker version >/dev/null 2>&1; then
            success "✓ Docker命令访问正常"
        else
            warn "✗ Docker命令访问失败"
        fi
    fi
}

# 创建用户环境配置
create_user_env() {
    local username="$1"
    local home_dir
    home_dir=$(eval echo "~$username")

    note "为用户 $username 创建环境配置..."

    # 创建.bashrc.d目录
    mkdir -p "$home_dir/.bashrc.d"

    # 创建Docker环境配置
    cat > "$home_dir/.bashrc.d/docker-env.sh" << 'EOF'
# Docker环境变量和别名
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Docker别名
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias dimg='docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"'
alias dvol='docker volume ls'
alias dnet='docker network ls'
alias drm='docker rm -f'
alias drmi='docker rmi -f'

# Containerd/Nerdctl别名
if command -v nerdctl >/dev/null 2>&1; then
    alias nps='nerdctl ps --format "table {{.Name}}\t{{.Image}}\t{{.Status}}"'
    alias nimg='nerdctl images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"'
    alias nvol='nerdctl volume ls'
    alias nnet='nerdctl network ls'
fi

# 提示函数
docker_info() {
    if command -v docker >/dev/null 2>&1; then
        echo "=== Docker信息 ==="
        docker version --format '{{.Server.Version}}' 2>/dev/null && echo "版本: $(docker version --format '{{.Server.Version}}' 2>/dev/null)"
        docker info 2>/dev/null | grep -E "Server Version|Storage Driver|Cgroup Driver" || echo "无法获取Docker信息"
    else
        echo "Docker未安装或不可访问"
    fi
}
EOF

    # 设置文件权限
    chown -R "$username:$username" "$home_dir/.bashrc.d"

    # 更新.bashrc
    if ! grep -q "docker-env.sh" "$home_dir/.bashrc" 2>/dev/null; then
        echo 'if [ -f ~/.bashrc.d/docker-env.sh ]; then . ~/.bashrc.d/docker-env.sh; fi' >> "$home_dir/.bashrc"
        chown "$username:$username" "$home_dir/.bashrc"
    fi

    success "用户环境配置完成"
}

# 主函数
main() {
    local username=""
    local revoke=false
    local list=false
    local all=false

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                username="$2"
                shift 2
                ;;
            -g|--group)
                GROUP="$2"
                shift 2
                ;;
            -r|--revoke)
                revoke=true
                shift
                ;;
            -l|--list)
                list=true
                shift
                ;;
            -a|--all)
                all=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                if [ -z "$username" ]; then
                    username="$1"
                else
                    error "未知参数: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # 如果没有指定用户，使用当前用户
    if [ -z "$username" ] && [ "$list" = false ] && [ "$all" = false ]; then
        username="$(logname 2>/dev/null || echo "$SUDO_USER")"
        if [ -z "$username" ]; then
            error "无法确定当前用户，请使用 -u 参数指定用户名"
            exit 1
        fi
    fi

    # 检查root权限 (除了列出操作)
    if [ "$list" = false ]; then
        check_root
    fi

    # 检测系统
    detect_system

    # 执行相应操作
    if [ "$list" = true ]; then
        list_authorized_users
    elif [ "$all" = true ]; then
        authorize_all_users
    elif [ "$revoke" = true ]; then
        revoke_user_permissions "$username"
        verify_permissions "$username"
    else
        authorize_docker_user "$username"
        create_user_env "$username"
        verify_permissions "$username"

        echo
        note "授权完成！用户 $username 现在可以："
        note "  - 无需sudo使用docker命令"
        note "  - 管理Docker服务 (start/stop/restart)"
        note "  - 使用docker-compose"
        note "  - 管理containerd/nerdctl"
        echo
        note "请让用户重新登录或执行以下命令使权限生效:"
        note "  newgrp docker"
        note "  或重新登录系统"
    fi
}

# 执行主函数
main "$@"