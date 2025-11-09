#!/bin/bash

# 用户管理菜单脚本
# 提供图形化界面来管理容器运行时用户权限

set -e

# 获取脚本目录
parent_path="$(cd "$(dirname "$0")" && pwd)"
source "$parent_path/tools/common.sh"

h1 "容器运行时用户管理工具"

# 显示主菜单
show_main_menu() {
    PS3=$'\033[32m请选择操作: \033[0m'
    local options=(
        "授权当前用户"
        "授权指定用户"
        "授权所有普通用户"
        "撤销用户权限"
        "列出已授权用户"
        "验证用户权限"
        "创建新用户并授权"
        "系统用户管理"
        "退出"
    )

    select choice in "${options[@]}"; do
        case "$choice" in
            "授权当前用户")
                authorize_current_user
                ;;
            "授权指定用户")
                authorize_specific_user
                ;;
            "授权所有普通用户")
                authorize_all_users
                ;;
            "撤销用户权限")
                revoke_user_permissions
                ;;
            "列出已授权用户")
                list_authorized_users
                ;;
            "验证用户权限")
                verify_user_permissions
                ;;
            "创建新用户并授权")
                create_and_authorize_user
                ;;
            "系统用户管理")
                system_user_management
                ;;
            "退出")
                exit 0
                ;;
            *)
                echo "无效的选项，请重新选择！"
                ;;
        esac

        echo
        note "按回车键返回主菜单..."
        read -r
        show_main_menu
        break
    done
}

# 授权当前用户
authorize_current_user() {
    local current_user="${SUDO_USER:-$(logname 2>/dev/null)}"
    if [ -n "$current_user" ]; then
        h2 "授权当前用户: $current_user"
        sudo bash "$parent_path/tools/authorize_user.sh" -u "$current_user"
    else
        error "无法确定当前用户，请以root权限运行或手动指定用户"
    fi
}

# 授权指定用户
authorize_specific_user() {
    while true; do
        read -r -p "请输入要授权的用户名 (输入 'back' 返回): " username
        if [ "$username" = "back" ]; then
            return
        elif [ -n "$username" ]; then
            h2 "授权用户: $username"
            sudo bash "$parent_path/tools/authorize_user.sh" -u "$username"
            break
        else
            error "用户名不能为空"
        fi
    done
}

# 授权所有普通用户
authorize_all_users() {
    h2 "授权所有普通用户"
    echo "这将为系统中所有UID >= 1000的用户授权Docker权限"
    read -r -p "确认继续? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo bash "$parent_path/tools/authorize_user.sh" -a
    else
        note "操作已取消"
    fi
}

# 撤销用户权限
revoke_user_permissions() {
    while true; do
        read -r -p "请输入要撤销权限的用户名 (输入 'back' 返回): " username
        if [ "$username" = "back" ]; then
            return
        elif [ -n "$username" ]; then
            h2 "撤销用户权限: $username"
            sudo bash "$parent_path/tools/authorize_user.sh" -u "$username" -r
            break
        else
            error "用户名不能为空"
        fi
    done
}

# 列出已授权用户
list_authorized_users() {
    h2 "已授权用户列表"
    sudo bash "$parent_path/tools/authorize_user.sh" -l
}

# 验证用户权限
verify_user_permissions() {
    while true; do
        read -r -p "请输入要验证的用户名 (输入 'back' 返回): " username
        if [ "$username" = "back" ]; then
            return
        elif [ -n "$username" ]; then
            h2 "验证用户权限: $username"

            # 检查用户是否存在
            if ! id "$username" >/dev/null 2>&1; then
                error "用户 $username 不存在"
                continue
            fi

            # 检查docker组成员
            if id -nG "$username" | grep -qw docker; then
                success "✓ 用户在docker组中"
            else
                warn "✗ 用户不在docker组中"
            fi

            # 检查sudo权限
            if sudo -l -U "$username" 2>/dev/null | grep -q "docker\|containerd"; then
                success "✓ 用户具有sudo免密权限"
            else
                warn "✗ 用户无sudo免密权限"
            fi

            # 测试Docker访问
            if command -v docker >/dev/null 2>&1; then
                if sudo -u "$username" docker version >/dev/null 2>&1; then
                    success "✓ Docker命令访问正常"
                else
                    warn "✗ Docker命令访问失败"
                fi
            else
                note "Docker未安装，跳过Docker访问测试"
            fi

            break
        else
            error "用户名不能为空"
        fi
    done
}

# 创建新用户并授权
create_and_authorize_user() {
    h2 "创建新用户并授权"

    while true; do
        read -r -p "请输入新用户名 (输入 'back' 返回): " new_username
        if [ "$new_username" = "back" ]; then
            return
        elif [ -n "$new_username" ]; then
            # 检查用户是否已存在
            if id "$new_username" >/dev/null 2>&1; then
                warn "用户 $new_username 已存在"
                continue
            fi

            # 获取用户信息
            read -r -p "请输入用户描述 (可选): " user_comment
            read -r -s -p "请输入用户密码: " user_password
            echo
            read -r -s -p "确认密码: " user_password_confirm
            echo

            if [ "$user_password" != "$user_password_confirm" ]; then
                error "密码不匹配，请重试"
                continue
            fi

            if [ -z "$user_password" ]; then
                error "密码不能为空"
                continue
            fi

            note "正在创建用户 $new_username..."

            # 创建用户
            if command -v useradd >/dev/null 2>&1; then
                if [ -n "$user_comment" ]; then
                    echo "$user_password" | sudo -S useradd -m -c "$user_comment" -s /bin/bash "$new_username"
                else
                    echo "$user_password" | sudo -S useradd -m -s /bin/bash "$new_username"
                fi
                echo "$user_password" | sudo -S passwd "$new_username"
            else
                error "useradd命令不可用，无法创建用户"
                return
            fi

            success "用户 $new_username 创建成功"

            # 立即授权
            note "为新用户授权Docker权限..."
            sudo bash "$parent_path/tools/authorize_user.sh" -u "$new_username"

            break
        else
            error "用户名不能为空"
        fi
    done
}

# 系统用户管理
system_user_management() {
    PS3=$'\033[32m请选择系统用户管理操作: \033[0m'
    local sys_options=(
        "列出所有系统用户"
        "列出所有普通用户"
        "查看用户详细信息"
        "修改用户密码"
        "删除用户"
        "返回主菜单"
    )

    select choice in "${sys_options[@]}"; do
        case "$choice" in
            "列出所有系统用户")
                list_all_users
                ;;
            "列出所有普通用户")
                list_normal_users
                ;;
            "查看用户详细信息")
                show_user_details
                ;;
            "修改用户密码")
                change_user_password
                ;;
            "删除用户")
                delete_user
                ;;
            "返回主菜单")
                return
                ;;
            *)
                echo "无效的选项，请重新选择！"
                ;;
        esac

        echo
        note "按回车键继续..."
        read -r
        system_user_management
        break
    done
}

# 列出所有系统用户
list_all_users() {
    h2 "所有系统用户"
    echo "用户名\t\tUID\t\t主目录\t\tShell"
    echo "------------------------------------------------------------"
    while IFS=: read -r username _ uid _ _ home shell _; do
        printf "%-15s\t%-10s\t%-20s\t%s\n" "$username" "$uid" "$home" "$shell"
    done < /etc/passwd
}

# 列出所有普通用户
list_normal_users() {
    h2 "普通用户 (UID >= 1000)"
    echo "用户名\t\tUID\t\t主目录\t\tShell"
    echo "------------------------------------------------------------"
    while IFS=: read -r username _ uid _ _ home shell _; do
        if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
            printf "%-15s\t%-10s\t%-20s\t%s\n" "$username" "$uid" "$home" "$shell"
        fi
    done < /etc/passwd
}

# 查看用户详细信息
show_user_details() {
    read -r -p "请输入要查看的用户名: " username
    if [ -n "$username" ] && id "$username" >/dev/null 2>&1; then
        h2 "用户详细信息: $username"

        echo "基本信息:"
        id "$username"

        echo
        echo "用户组:"
        groups "$username"

        echo
        echo "登录记录:"
        last -n 5 "$username" 2>/dev/null || echo "无登录记录"

        if [ -d "/home/$username" ]; then
            echo
            echo "主目录信息:"
            ls -la "/home/$username" | head -10
        fi
    else
        error "用户 $username 不存在"
    fi
}

# 修改用户密码
change_user_password() {
    read -r -p "请输入要修改密码的用户名: " username
    if [ -n "$username" ] && id "$username" >/dev/null 2>&1; then
        h2 "修改用户密码: $username"
        sudo passwd "$username"
    else
        error "用户 $username 不存在"
    fi
}

# 删除用户
delete_user() {
    read -r -p "请输入要删除的用户名: " username
    if [ -n "$username" ] && id "$username" >/dev/null 2>&1; then
        if [ "$username" = "root" ]; then
            error "不能删除root用户"
            return
        fi

        echo "警告: 这将永久删除用户 $username 及其主目录"
        read -r -p "确认删除? (输入 'DELETE' 确认): " confirm
        if [ "$confirm" = "DELETE" ]; then
            h2 "删除用户: $username"
            sudo userdel -r "$username"
            success "用户 $username 已删除"
        else
            note "操作已取消"
        fi
    else
        error "用户 $username 不存在"
    fi
}

# 检查运行权限
check_permissions() {
    if [ "$(id -u)" -eq 0 ]; then
        note "以root权限运行，拥有完整管理权限"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        note "具有sudo权限，可以执行管理操作"
    else
        warn "当前用户权限不足，某些操作可能需要sudo"
        note "建议使用: sudo $0"
    fi
}

# 主函数
main() {
    note "欢迎使用容器运行时用户管理工具"
    echo

    check_permissions
    echo

    show_main_menu
}

# 执行主函数
main "$@"