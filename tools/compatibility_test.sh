#!/bin/bash

# 系统兼容性测试脚本
# 用于测试安装脚本在不同系统上的兼容性

set -e

# 获取脚本目录
parent_path="$(cd "$(dirname "$0")" && pwd)"
source "$parent_path/common.sh"

h1 "容器安装器 - 系统兼容性测试"

# 测试系统检测功能
test_system_detection() {
    h2 "测试系统检测功能"

    # 执行系统检测
    detect_system

    # 显示检测到的系统信息
    note "系统检测结果:"
    echo "  原始架构: $(uname -m)"
    echo "  标准架构: $ARCH"
    echo "  发行版: $DISTRO"
    echo "  版本: $VERSION"
    echo "  包管理器: $PKG_MANAGER"
    if [ -n "$CODENAME" ]; then
        echo "  代号: $CODENAME"
    fi

    # 验证架构检测
    case $ARCH in
        amd64|arm64|armv7l|386)
            success "架构检测正确: $ARCH"
            ;;
        *)
            warn "未知架构: $ARCH"
            ;;
    esac

    # 验证发行版检测
    case $DISTRO in
        ubuntu|debian|centos|rhel|fedora|sles|opensuse-leap)
            success "发行版检测正确: $DISTRO"
            ;;
        *)
            warn "未知发行版: $DISTRO"
            ;;
    esac

    # 验证包管理器检测
    case $PKG_MANAGER in
        apt|yum|dnf|zypper|pacman)
            success "包管理器检测正确: $PKG_MANAGER"
            ;;
        *)
            warn "未知包管理器: $PKG_MANAGER"
            ;;
    esac
}

# 测试工具依赖
test_dependencies() {
    h2 "测试工具依赖"

    local required_tools=("wget" "curl" "tar" "systemctl")
    local missing_tools=()

    note "检查必要工具..."

    for tool in "${required_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            success "$tool 已安装"
        else
            warn "$tool 未安装"
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        error "缺少必要工具: ${missing_tools[*]}"
        note "建议安装命令:"
        case $PKG_MANAGER in
            apt)
                echo "  sudo apt-get update && sudo apt-get install -y ${missing_tools[*]}"
                ;;
            yum|dnf)
                echo "  sudo $PKG_MANAGER install -y ${missing_tools[*]}"
                ;;
            zypper)
                echo "  sudo zypper install -y ${missing_tools[*]}"
                ;;
            pacman)
                echo "  sudo pacman -S --noconfirm ${missing_tools[*]}"
                ;;
        esac
    else
        success "所有必要工具已安装"
    fi
}

# 测试网络连接
test_network_connectivity() {
    h2 "测试网络连接"

    note "测试网络连接..."

    if test_network; then
        success "网络连接正常"
    else
        warn "网络连接可能存在问题"
        note "将尝试测试特定下载源..."
    fi

    # 测试Docker下载源
    local docker_urls=(
        "https://download.docker.com"
        "https://github.com"
        "https://private-deploy.oss-cn-beijing.aliyuncs.com"
    )

    note "测试Docker/Containerd下载源..."
    for url in "${docker_urls[@]}"; do
        if curl -s --connect-timeout 5 "$url" >/dev/null 2>&1; then
            success "$url 连接正常"
        else
            warn "$url 连接失败"
        fi
    done
}

# 测试权限
test_permissions() {
    h2 "测试系统权限"

    # 检查root权限
    if [ "$(id -u)" -eq 0 ]; then
        success "具有root权限"
    else
        warn "当前用户不是root"
        note "某些操作可能需要sudo权限"
    fi

    # 检查systemctl权限
    if systemctl --version >/dev/null 2>&1; then
        success "systemctl可用"
    else
        error "systemctl不可用，可能无法管理服务"
    fi

    # 检查目录写入权限
    local test_dirs=("/usr/bin" "/etc/systemd/system" "/usr/local")
    for dir in "${test_dirs[@]}"; do
        if [ -d "$dir" ] && [ -w "$dir" ]; then
            success "目录 $dir 可写"
        else
            warn "目录 $dir 不可写"
        fi
    done
}

# 测试现有容器运行时
test_existing_runtimes() {
    h2 "测试现有容器运行时"

    local runtimes=("docker" "dockerd" "containerd" "podman" "nerdctl")

    for runtime in "${runtimes[@]}"; do
        if command -v "$runtime" >/dev/null 2>&1; then
            local version=$("$runtime" --version 2>/dev/null || echo "未知版本")
            warn "$runtime 已安装 ($version)"
        else
            success "$runtime 未安装"
        fi
    done
}

# 测试存储空间
test_storage_space() {
    h2 "测试存储空间"

    note "检查磁盘空间..."

    # 检查根目录空间
    local root_space=$(df / | awk 'NR==2 {print $4}')
    local root_space_gb=$((root_space / 1024 / 1024))

    if [ "$root_space_gb" -gt 5 ]; then
        success "根目录可用空间: ${root_space_gb}GB"
    else
        warn "根目录可用空间不足: ${root_space_gb}GB (建议至少5GB)"
    fi

    # 检查/var目录空间（Docker默认存储位置）
    if [ -d /var ]; then
        local var_space=$(df /var 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
        local var_space_gb=$((var_space / 1024 / 1024))

        if [ "$var_space_gb" -gt 5 ]; then
            success "/var目录可用空间: ${var_space_gb}GB"
        elif [ "$var_space_gb" -gt 0 ]; then
            warn "/var目录可用空间不足: ${var_space_gb}GB (建议至少5GB)"
        fi
    fi
}

# 生成兼容性报告
generate_report() {
    h2 "兼容性评估报告"

    echo
    bold "=== 系统兼容性评估 ==="
    echo

    # 总体评估
    local issues=0

    # 检查关键依赖
    if ! command -v systemctl >/dev/null 2>&1; then
        ((issues++))
        echo "❌ 缺少systemctl (关键依赖)"
    fi

    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        ((issues++))
        echo "❌ 缺少网络下载工具 (关键依赖)"
    fi

    # 检查架构支持
    case $ARCH in
        amd64|arm64)
            echo "✅ 架构支持: $ARCH (完全支持)"
            ;;
        armv7l|386)
            echo "⚠️  架构支持: $ARCH (有限支持)"
            ;;
        *)
            ((issues++))
            echo "❌ 架构支持: $ARCH (不支持)"
            ;;
    esac

    # 检查发行版支持
    case $DISTRO in
        ubuntu|debian|centos|rhel|fedora)
            echo "✅ 发行版支持: $DISTRO (完全支持)"
            ;;
        sles|opensuse-leap)
            echo "⚠️  发行版支持: $DISTRO (有限支持)"
            ;;
        *)
            echo "⚠️  发行版支持: $DISTRO (未测试)"
            ;;
    esac

    # 检查权限
    if [ "$(id -u)" -eq 0 ]; then
        echo "✅ 权限检查: root权限"
    else
        echo "⚠️  权限检查: 非root用户，可能需要sudo"
    fi

    echo
    if [ $issues -eq 0 ]; then
        success "系统完全兼容，可以正常安装"
        exit 0
    else
        error "发现 $issues 个兼容性问题，建议解决后再安装"
        exit 1
    fi
}

# 主测试流程
main() {
    echo "开始系统兼容性测试..."
    echo

    test_system_detection
    echo
    test_dependencies
    echo
    test_network_connectivity
    echo
    test_permissions
    echo
    test_existing_runtimes
    echo
    test_storage_space
    echo
    generate_report
}

# 执行测试
main "$@"