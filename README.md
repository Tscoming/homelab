# 🏠 Homelab 基础设施仓库

![GitHub last commit](https://img.shields.io/github/last-commit/Tscoming/homelab)
![GitHub repo size](https://img.shields.io/github/repo-size/Tscoming/homelab)
![GitHub issues](https://img.shields.io/github/issues/Tscoming/homelab)
![License](https://img.shields.io/github/license/Tscoming/homelab)

> 长期维护、生产级别的 **Homelab 基础设施即代码 (IaC)** 仓库  
> 用于管理计算、存储、网络、服务和自动化。

---

## 📌 概述

这是我的 Homelab 基础设施的**单一可信源**。

其设计目标是管理以下内容的完整生命周期：

- 物理机和虚拟机
- 操作系统初始化
- 配置管理
- 容器化工作负载
- Kubernetes 工作负载
- 基础设施配置
- 监控、安全和备份

**核心目标**

- 可重复的部署
- 可审计的变更
- 自动化运维
- 长期可维护性

---

## 🧠 设计原则

- 基础设施即代码优先
- 幂等自动化
- 环境分离（local / lab / prod）
- 最小化人工干预
- 文档驱动的运维

> 如果没有文档记录，它就不存在。

---

## 🗂️ 仓库结构

```text
homelab/
├── docs/          # 架构、运维手册、ADR
├── inventory/     # 主机和环境清单
├── scripts/       # 初始化和实用脚本
├── ansible/       # 配置管理
├── docker/        # Docker 镜像和 Compose 栈
├── kubernetes/    # Kubernetes 清单和 Helm
├── terraform/     # 基础设施配置
├── cloud-init/    # 系统初始化配置
├── services/      # 逻辑服务定义
├── monitoring/    # 可观测性栈
├── security/      # 加固和安全策略
├── backups/       # 备份和恢复自动化
├── assets/       # 图表和静态资源
└── .github/      # CI 工作流和模板
```

---

## 🚀 快速开始

### 1️⃣ 克隆仓库

```bash
git clone https://github.com/Tscoming/homelab.git
cd homelab
```

### 2️⃣ 初始化 Ubuntu 系统（可选）

```bash
# 方式一：克隆仓库后执行
sudo scripts/bootstrap/init-ubuntu.sh

# 方式二：直接远程执行（无需克隆）
curl -fsSL https://raw.githubusercontent.com/Tscoming/homelab/main/scripts/bootstrap/init-ubuntu.sh | sudo bash
```

此脚本执行以下操作：
- 安装基础工具包（curl, wget, git, vim, htop, tmux 等）
- 配置时区为 Asia/Shanghai 和 NTP 时间同步
- 自动切换 APT 为国内镜像（阿里云/腾讯云）
- 系统调优（文件描述符、网络参数等）
- SSH 基础加固

> ⚠️ 首次在新机器上运行时建议执行此脚本

### 3️⃣ 安装 Docker

```bash
# 方式一：克隆仓库后执行
sudo scripts/bootstrap/install-docker.sh

# 方式二：直接远程执行（无需克隆）
curl -fsSL https://raw.githubusercontent.com/Tscoming/homelab/main/scripts/bootstrap/install-docker.sh | sudo bash
```

可选参数：
```bash
# 使用官方镜像（默认使用国内镜像）
USE_CHINA_MIRROR=false sudo scripts/bootstrap/install-docker.sh

# 指定 Docker 版本
DOCKER_VERSION=24.0 sudo scripts/bootstrap/install-docker.sh

# 跳过配置，仅安装
SKIP_CONFIG=true sudo scripts/bootstrap/install-docker.sh
```

### 4️⃣ 安装 Node.js

```bash
# 方式一：克隆仓库后执行
sudo scripts/bootstrap/install-nodejs.sh

# 方式二：直接远程执行（无需克隆）
curl -fsSL https://raw.githubusercontent.com/Tscoming/homelab/main/scripts/bootstrap/install-nodejs.sh | sudo bash
```

可选参数：
```bash
# 安装 Node.js 18.x（默认 22.x）
NODE_VERSION=18 sudo scripts/bootstrap/install-nodejs.sh

# 使用官方 npm 镜像
USE_CHINA_MIRROR=false sudo scripts/bootstrap/install-nodejs.sh

# 不安装 pnpm
INSTALL_PNPM=false sudo scripts/bootstrap/install-nodejs.sh

# 安装 yarn
INSTALL_YARN=true sudo scripts/bootstrap/install-nodejs.sh
```

### 5️⃣ 对 lab 环境运行 Ansible

```bash
cd ansible
ansible-playbook -i ../inventory/lab/hosts.yaml playbooks/bootstrap.yml
```

---

## 🧰 常用操作

### ▶ 初始化 Ubuntu 系统

```bash
# 方式一：克隆仓库后执行
sudo scripts/bootstrap/init-ubuntu.sh

# 方式二：直接远程执行（无需克隆）
curl -fsSL https://raw.githubusercontent.com/Tscoming/homelab/main/scripts/bootstrap/init-ubuntu.sh | sudo bash
```

### ▶ 安装 Docker

```bash
# 方式一：克隆仓库后执行
sudo scripts/bootstrap/install-docker.sh

# 方式二：直接远程执行（无需克隆）
curl -fsSL https://raw.githubusercontent.com/Tscoming/homelab/main/scripts/bootstrap/install-docker.sh | sudo bash
```

### ▶ 安装 Node.js

```bash
# 方式一：克隆仓库后执行
sudo scripts/bootstrap/install-nodejs.sh

# 方式二：直接远程执行（无需克隆）
curl -fsSL https://raw.githubusercontent.com/Tscoming/homelab/main/scripts/bootstrap/install-nodejs.sh | sudo bash
```

### ▶ 切换 APT 为国内镜像

```bash
# 方式一：克隆仓库后执行
sudo scripts/bootstrap/set-apt-cn.sh

# 方式二：直接远程执行（无需克隆）
curl -fsSL https://raw.githubusercontent.com/Tscoming/homelab/main/scripts/bootstrap/set-apt-cn.sh | sudo bash
```

### ▶ 部署 Docker Compose 栈

```bash
cd docker/compose/media
docker compose up -d
```

### ▶ 硬件自动化（Redfish / iDRAC）

```bash
scripts/hardware/idrac-redfish.sh
```

---

## 🌍 环境

| 环境 | 说明 |
|------|------|
| local | 本地测试 |
| lab | 测试环境 / 实验 |
| prod | 生产环境 |

每个环境都有独立的清单和变量文件。

---

## 🔐 安全指南

- 绝不提交密钥
- 使用 .env 文件或外部密钥管理器
- 敏感文件通过 .gitignore 排除
- SSH 加固最小化且可逆

---

## 📖 文档

| 分类 | 位置 |
|------|------|
| 架构 | docs/architecture/ |
| 运维手册 | docs/runbooks/ |
| 标准规范 | docs/standards/ |
| 决策记录 (ADR) | docs/decisions/ |

---

## 🛣️ 路线图

- [x] 基础初始化脚本
- [x] Docker & Compose 工作负载
- [ ] 完整的 Ansible role 覆盖
- [ ] 集中式监控栈
- [ ] Kubernetes 迁移路径
- [ ] 灾难恢复自动化

---

## 🤝 贡献

这是个人 Homelab 项目，欢迎贡献：

- Issues
- Pull requests
- 架构讨论

---

## 📄 许可证

MIT License

---

## ✨ 理念

Homelab 不只是运行服务。  
它是理解系统的途径。
