#!/bin/bash

# 检查参数
if [[ $# != 1 ]]; then
    echo "Usage: $0 USERNAME"
    echo "Example: $0 laiye"
    exit 1
fi

USERNAME="$1"

# 验证用户是否存在
if ! id -u "$USERNAME" >/dev/null 2>&1; then
    echo "Error: User '$USERNAME' does not exist"
    exit 1
fi

# 检查Docker是否安装
if ! command -v docker >/dev/null 2>&1; then
    echo "Warning: Docker is not installed"
else
    # 配置Docker权限
    echo "Configuring Docker permissions for user $USERNAME..."
    if [ -e "/usr/bin/docker" ]; then
        chmod 755 /usr/bin/docker
    fi
    
    if [ -e "/usr/bin/docker-compose" ]; then
        chmod 755 /usr/bin/docker-compose
    fi
    
    # 将用户加入docker组
    if getent group docker >/dev/null; then
        usermod -aG docker "$USERNAME"
    else
        echo "Warning: Docker group does not exist"
    fi
fi

# 检查nerdctl是否安装
if ! command -v nerdctl >/dev/null 2>&1; then
    echo "Warning: nerdctl is not installed"
else
    # 配置nerdctl权限
    echo "Configuring nerdctl permissions for user $USERNAME..."
    if [ -e "/usr/local/bin/nerdctl" ]; then
        chown root:"$USERNAME" /usr/local/bin/nerdctl
        chmod 750 /usr/local/bin/nerdctl
        chmod +s /usr/local/bin/nerdctl
    fi
    
    # 将用户加入containerd组(如果存在)
    if getent group containerd >/dev/null; then
        usermod -aG containerd "$USERNAME"
    fi
fi

# 输出结果摘要
echo -e "\nPermission configuration summary for $USERNAME:"
groups "$USERNAME"

# 提示用户需要重新登录
echo -e "\nNote: User $USERNAME needs to log out and log back in for changes to take effect."