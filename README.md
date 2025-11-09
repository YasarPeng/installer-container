# 容器运行时安装器

一个兼容多种Linux发行版的容器运行时安装工具，支持Docker和Containerd的自动化安装。

## 🚀 主要特性

- **多发行版支持**: Ubuntu、Debian、CentOS、RHEL、Fedora、SUSE等
- **多架构支持**: x86_64/amd64、aarch64/arm64、armv7l、i386等
- **智能检测**: 自动检测系统环境、依赖和权限
- **容错下载**: 支持多个下载源，自动重试和回退
- **服务管理**: 完整的systemd服务配置和管理
- **兼容性测试**: 提供系统兼容性预检查功能

## 📋 系统要求

### 支持的操作系统
- **Ubuntu** 18.04+
- **Debian** 9+
- **CentOS** 7+
- **RHEL** 7+
- **Fedora** 30+
- **openSUSE Leap** 15+
- **SUSE Linux Enterprise Server** 12+

### 支持的系统架构
- **x86_64 / amd64** (完全支持)
- **aarch64 / arm64** (完全支持)
- **armv7l / armhf** (有限支持)
- **i386** (有限支持)

### 必要工具
- wget 或 curl
- tar
- systemctl (systemd)
- root权限或sudo权限

## 🔧 快速开始

### 1. 兼容性检查 (推荐)

```bash
# 检查系统兼容性
bash tools/compatibility_test.sh
```

### 2. 下载安装包 (可选)

```bash
# 预下载运行时安装包
bash tools/download_package.sh
```

### 3. 交互式安装

```bash
# 运行主安装脚本 (会自动询问用户授权)
bash install.sh
```

### 4. 直接安装特定版本

```bash
# 安装Docker (指定版本和存储路径)
bash docker/install.sh /var/lib/docker 24.0.9

# 安装Containerd (指定版本和存储路径)
bash containerd/install.sh /data/containerd 1.7.7

# 安装后授权用户
sudo bash tools/authorize_user.sh
```

### 5. 用户权限管理 (推荐)

```bash
# 图形化用户管理工具
bash user_manager.sh

# 或直接命令行授权
sudo bash tools/authorize_user.sh -u username
```

## 📦 支持的版本

### Docker
- 19.03.15
- 20.10.24 (默认)
- 24.0.9
- 25.0.5
- 26.1.4

### Containerd (nerdctl-full)
- 1.7.6 (默认)
- 1.7.7
- 2.0.0
- 2.0.2
- 2.0.3

## 🛠️ 功能说明

### 系统初始化
主安装脚本会自动执行以下系统初始化:
- 配置系统限制
- 禁用swap
- 启用br_netfilter模块
- 启用IPv4转发
- 配置IPVS
- 禁用防火墙 (可选)

### Docker安装特性
- 支持多种下载源 (官方GitHub + 国内备用源)
- 自动配置daemon.json
- systemd服务配置
- docker-compose自动安装
- 用户权限配置

### Containerd安装特性
- 使用nerdctl-full包 (包含containerd + nerdctl + buildkit)
- 支持多架构下载
- 自动配置config.toml
- 支持国内镜像源
- 服务自动启动

## 👥 用户权限管理

### 一键授权普通用户

安装完成后，可以为普通用户授权，无需sudo即可管理容器：

```bash
# 为当前用户授权
sudo bash tools/authorize_user.sh

# 为指定用户授权
sudo bash tools/authorize_user.sh -u username

# 为所有普通用户授权
sudo bash tools/authorize_user.sh -a

# 撤销用户权限
sudo bash tools/authorize_user.sh -u username -r

# 列出已授权用户
sudo bash tools/authorize_user.sh -l
```

### 用户管理工具

使用图形化菜单管理用户权限：

```bash
# 启动用户管理工具
bash user_manager.sh
```

### 用户授权功能

授权后，普通用户可以：
- ✅ 无需sudo使用 `docker` 命令
- ✅ 管理Docker服务 (`start/stop/restart`)
- ✅ 使用 `docker-compose`
- ✅ 管理containerd/nerdctl
- ✅ 查看服务状态和日志

### 环境配置

授权后会自动创建用户环境配置文件：
- Docker命令别名 (`dps`, `dimg`, `drm` 等)
- Containerd/Nerdctl别名 (`nps`, `nimg` 等)
- 环境变量优化
- 便捷的查询函数

> **注意**: 授权后需要重新登录或执行 `newgrp docker` 使权限生效

## 🔄 卸载

```bash
# 卸载Docker
bash docker/uninstall.sh

# 卸载Containerd
bash containerd/uninstall.sh

# 完全卸载 (包括配置)
bash uninstall.sh

# 撤销用户权限
sudo bash tools/authorize_user.sh -u username -r
```

## 🐛 故障排除

### 常见问题

1. **权限不足**
   ```bash
   sudo bash install.sh
   ```

2. **网络连接问题**
   ```bash
   # 手动下载安装包到对应目录
   mkdir -p docker/x86_64 containerd/x86_64
   # 将下载的包放入对应目录
   ```

3. **systemctl不可用**
   - 仅支持systemd系统
   - 检查系统是否使用systemd

4. **依赖工具缺失**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install wget curl tar

   # CentOS/RHEL/Fedora
   sudo yum install wget curl tar
   ```

5. **用户权限问题**
   ```bash
   # 检查用户是否在docker组
   groups $USER | grep docker

   # 重新登录或切换组
   newgrp docker

   # 手动授权用户
   sudo bash tools/authorize_user.sh -u $USER
   ```

6. **sudo权限不足**
   ```bash
   # 确保用户有sudo权限
   sudo -v

   # 检查sudo配置
   sudo visudo
   ```

### 日志查看

```bash
# 查看服务状态
systemctl status docker
systemctl status containerd

# 查看服务日志
journalctl -u docker -f
journalctl -u containerd -f
```

## 📁 项目结构

```
├── install.sh              # 主安装脚本
├── uninstall.sh            # 主卸载脚本
├── user_manager.sh         # 用户管理工具 (图形化菜单)
├── docker/                 # Docker相关
│   ├── install.sh          # Docker安装脚本
│   ├── uninstall.sh        # Docker卸载脚本
│   └── *.service           # systemd服务文件
├── containerd/             # Containerd相关
│   ├── install.sh          # Containerd安装脚本
│   └── uninstall.sh        # Containerd卸载脚本
└── tools/                  # 工具脚本
    ├── common.sh           # 通用函数库
    ├── compatibility_test.sh  # 兼容性测试
    ├── authorize_user.sh   # 用户授权脚本
    ├── download_package.sh # 下载安装包
    └── *.sh               # 系统配置脚本
```

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目。

## 📄 许可证

MIT License
