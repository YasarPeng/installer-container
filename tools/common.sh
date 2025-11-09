#!/bin/bash

set +e
set -o noglob

# 系统兼容性函数
detect_system() {
    # 检测操作系统类型
    OS_TYPE="$(uname -s)"

    # 检测系统架构
    ARCH="$(uname -m)"
    case $ARCH in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armhf) ARCH="armv7l" ;;
        armv6l) ARCH="armv6l" ;;
        i386|i686) ARCH="386" ;;
        *)
            warn "不常见的系统架构: $ARCH"
            ;;
    esac

    # 针对不同操作系统的检测
    case "$OS_TYPE" in
        Linux)
            # 检测Linux发行版
            if [ -r /etc/os-release ]; then
                . /etc/os-release
                DISTRO="${ID,,}"  # 转换为小写
                VERSION="${VERSION_ID}"
                CODENAME="${VERSION_CODENAME}"
            elif [ -r /etc/redhat-release ]; then
                DISTRO="rhel"
                VERSION="$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)"
            elif [ -r /etc/debian_version ]; then
                DISTRO="debian"
                VERSION="$(cat /etc/debian_version)"
            else
                DISTRO="unknown"
                VERSION="unknown"
            fi

            # 检测包管理器
            if command -v apt-get >/dev/null 2>&1; then
                PKG_MANAGER="apt"
            elif command -v yum >/dev/null 2>&1; then
                PKG_MANAGER="yum"
            elif command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
            elif command -v zypper >/dev/null 2>&1; then
                PKG_MANAGER="zypper"
            elif command -v pacman >/dev/null 2>&1; then
                PKG_MANAGER="pacman"
            else
                PKG_MANAGER="unknown"
            fi
            ;;
        Darwin)
            DISTRO="macos"
            VERSION="$(sw_vers -productVersion)"
            PKG_MANAGER="brew"
            ;;
        *)
            DISTRO="unknown"
            VERSION="unknown"
            PKG_MANAGER="unknown"
            warn "不支持的操作系统: $OS_TYPE"
            ;;
    esac
}

# 检查必要工具
check_dependencies() {
    local missing_tools=()

    for tool in wget curl tar systemctl; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        error "缺少必要工具: ${missing_tools[*]}"
        install_dependencies "${missing_tools[@]}"
    fi
}

# 安装依赖
install_dependencies() {
    local tools=("$@")
    note "正在安装缺少的工具: ${tools[*]}"

    case "$PKG_MANAGER" in
        apt)
            apt-get update
            apt-get install -y "${tools[@]}"
            ;;
        yum|dnf)
            $PKG_MANAGER install -y "${tools[@]}"
            ;;
        zypper)
            zypper install -y "${tools[@]}"
            ;;
        pacman)
            pacman -S --noconfirm "${tools[@]}"
            ;;
    esac
}

# 服务管理函数
start_service() {
    local service="$1"
    systemctl daemon-reload
    systemctl enable "$service"
    systemctl start "$service"

    # 检查服务状态
    if systemctl is-active --quiet "$service"; then
        success "$service 服务启动成功"
    else
        error "$service 服务启动失败"
        return 1
    fi
}

stop_service() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        systemctl stop "$service"
    fi
    if systemctl is-enabled --quiet "$service"; then
        systemctl disable "$service"
    fi
}

# 网络连接测试
test_network() {
    local test_urls=("https://www.baidu.com" "https://www.google.com")
    local connected=false

    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 5 "$url" >/dev/null 2>&1; then
            connected=true
            break
        fi
    done

    if [ "$connected" = false ]; then
        warn "网络连接测试失败，请检查网络设置"
        return 1
    fi

    return 0
}

#
# Set Colors
#

# 兼容没有TERM变量的环境
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    bold=$(tput bold 2>/dev/null || echo "")
    underline=$(tput sgr 0 1 2>/dev/null || echo "")
    reset=$(tput sgr0 2>/dev/null || echo "")
    red=$(tput setaf 1 2>/dev/null || echo "")
    green=$(tput setaf 2 2>/dev/null || echo "")
    white=$(tput setaf 7 2>/dev/null || echo "")
    tan=$(tput setaf 3 2>/dev/null || echo "")
    blue=$(tput setaf 4 2>/dev/null || echo "")
else
    bold=""
    underline=""
    reset=""
    red=""
    green=""
    white=""
    tan=""
    blue=""
fi

#
# Headers and Logging
#

underline() { printf "${underline}${bold}%s${reset}\n" "$@"
}
h1() { printf "\n${underline}${bold}${blue}%s${reset}\n" "$@"
}
h2() { printf "\n${underline}${bold}${white}%s${reset}\n" "$@"
}
debug() { printf "${white}%s${reset}\n" "$@"
}
info() { printf "${white}➜ %s${reset}\n" "$@"
}
success() { printf "${green}✔ %s${reset}\n" "$@"
}
error() { printf "${red}✖ %s${reset}\n" "$@"
}
warn() { printf "${tan}➜ %s${reset}\n" "$@"
}
bold() { printf "${bold}%s${reset}\n" "$@"
}
note() { printf "\n${underline}${bold}${blue}Note:${reset} ${blue}%s${reset}\n" "$@"
}

set -e

function check_docker {
        if ! docker --version &> /dev/null
        then
                note "Need to install docker(19.06.0+) first and run this script again."
        fi

        # docker has been installed and check its version
        if [[ $(docker --version) =~ (([0-9]+)\.([0-9]+)([\.0-9]*)) ]]
        then
                docker_version=${BASH_REMATCH[1]}
                docker_version_part1=${BASH_REMATCH[2]}
                docker_version_part2=${BASH_REMATCH[3]}

                note "docker version: $docker_version"
                # the version of docker does not meet the requirement
                if [ "$docker_version_part1" -lt 19 ] || ([ "$docker_version_part1" -eq 19 ] && [ "$docker_version_part2" -lt 6 ])
                then
                        error "Need to upgrade docker package to 19.06.0+."
                        exit 1
                fi
        else
                error "Failed to parse docker version."
                exit 1
        fi
}


function check_dockercompose {
        if ! docker-compose --version &> /dev/null
        then
                error "Need to install docker-compose(1.18.0+) by yourself first and run this script again."
                exit 1
        fi

        # docker-compose has been installed, check its version
        if [[ $(docker-compose --version) =~ (([0-9]+)\.([0-9]+)([\.0-9]*)) ]]
        then
                docker_compose_version=${BASH_REMATCH[1]}
                docker_compose_version_part1=${BASH_REMATCH[2]}
                docker_compose_version_part2=${BASH_REMATCH[3]}

                note "docker-compose version: $docker_compose_version"
                # the version of docker-compose does not meet the requirement
                if [ "$docker_compose_version_part1" -lt 1 ] || ([ "$docker_compose_version_part1" -eq 1 ] && [ "$docker_compose_version_part2" -lt 18 ])
                then
                        error "Need to upgrade docker-compose package to 1.18.0+."
                        exit 1
                fi
        else
                error "Failed to parse docker-compose version."
                exit 1
        fi
}