#!/bin/bash
#
# install-dev-tools.sh - 安装开发工具和环境
# 
# 支持的工具:
#   - VSCode (Visual Studio Code)
#   - Postman
#   - Conda (Miniconda)
#   - Docker (可选)
#   - Node.js (可选)
#   - Git (可选)
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        # 对于 --help 选项，不检查 root 权限
        if [[ "$@" == *"--help"* ]] || [[ "$@" == *"-h"* ]]; then
            return 0
        fi
        log_warn "此脚本需要root权限运行，请使用 sudo"
        exit 1
    fi
}

# 更新系统包
update_system() {
    log_step "更新系统包索引..."
    apt update
    apt upgrade -y
    log_info "系统包更新完成"
}

# 安装基础依赖
install_dependencies() {
    log_step "安装基础依赖..."
    apt install -y \
        wget \
        curl \
        git \
        gnupg \
        ca-certificates \
        software-properties-common \
        apt-transport-https \
        unzip \
        zsh
    log_info "基础依赖安装完成"
}

# 安装 VSCode
install_vscode() {
    log_step "安装 Visual Studio Code..."
    
    if command -v code &> /dev/null; then
        log_warn "VSCode 已安装"
        return
    fi
    
    # 添加 Microsoft GPG key
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg
    
    # 添加 VSCode 仓库
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list
    
    # 安装 VSCode
    apt update
    apt install -y code
    
    log_info "VSCode 安装完成"
}

# 安装 Postman
install_postman() {
    log_step "安装 Postman..."
    
    if command -v postman &> /dev/null; then
        log_warn "Postman 已安装"
        return
    fi
    
    # 下载 Postman
    wget -O /tmp/postman.tar.gz https://dl.pstmn.io/download/latest/linux64
    
    # 解压到 /opt
    tar -xzf /tmp/postman.tar.gz -C /opt
    
    # 创建符号链接
    ln -sf /opt/Postman/Postman /usr/bin/postman
    
    # 清理
    rm -f /tmp/postman.tar.gz
    
    # 创建桌面快捷方式
    mkdir -p ~/.local/share/applications
    cat > ~/.local/share/applications/postman.desktop << 'EOF'
[Desktop Entry]
Name=Postman
Exec=postman
Icon=/opt/Postman/resources/app/assets/icon.png
Type=Application
Categories=Development;
EOF
    
    log_info "Postman 安装完成"
}

# 安装 Conda (Miniconda)
install_conda() {
    log_step "安装 Conda (Miniconda)..."
    
    if command -v conda &> /dev/null; then
        log_warn "Conda 已安装"
        return
    fi
    
    # 下载 Miniconda
    wget -O /tmp/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    
    # 安装 Miniconda
    bash /tmp/miniconda.sh -b -p /opt/conda
    
    # 创建符号链接
    ln -sf /opt/conda/bin/conda /usr/bin/conda
    ln -sf /opt/conda/bin/python /usr/bin/python-conda
    ln -sf /opt/conda/bin/pip /usr/bin/pip-conda
    
    # 初始化 Conda
    /opt/conda/bin/conda init bash
    
    # 清理
    rm -f /tmp/miniconda.sh
    
    log_info "Conda 安装完成"
    log_info "请重新登录shell以激活 Conda"
}

# 安装 Docker (可选)
install_docker() {
    log_step "安装 Docker..."
    
    if command -v docker &> /dev/null; then
        log_warn "Docker 已安装"
        return
    fi
    
    # 添加 Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # 添加 Docker 仓库
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    
    # 安装 Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # 启动 Docker
    systemctl start docker
    systemctl enable docker
    
    # 将当前用户添加到 docker 组
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
    fi
    
    log_info "Docker 安装完成"
}

# 安装 Node.js (可选)
install_nodejs() {
    log_step "安装 Node.js..."
    
    if command -v node &> /dev/null; then
        log_warn "Node.js 已安装: $(node --version)"
        return
    fi
    
    # 添加 NodeSource 仓库
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    
    # 安装 Node.js
    apt install -y nodejs
    
    log_info "Node.js 安装完成: $(node --version)"
}

# 安装 Zsh 和 Oh My Zsh (可选)
install_zsh() {
    log_step "安装 Zsh 和 Oh My Zsh..."
    
    if command -v zsh &> /dev/null; then
        log_warn "Zsh 已安装"
    else
        apt install -y zsh
    fi
    
    # 安装 Oh My Zsh (如果未安装)
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    log_info "Zsh 安装完成"
}

# 安装 Docker Compose (独立版本)
install_docker_compose() {
    log_step "安装 Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        log_warn "Docker Compose 已安装: $(docker-compose --version)"
        return
    fi
    
    # 下载 Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # 添加执行权限
    chmod +x /usr/local/bin/docker-compose
    
    # 创建符号链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_info "Docker Compose 安装完成: $(docker-compose --version)"
}

# 显示使用帮助
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
    --all           安装所有工具 (默认)
    --vscode        仅安装 VSCode
    --postman       仅安装 Postman
    --conda         仅安装 Conda
    --docker        仅安装 Docker
    --nodejs        仅安装 Node.js
    --zsh           仅安装 Zsh
    --help          显示此帮助信息

示例:
    sudo $0                  # 安装所有工具
    sudo $0 --vscode --postman  # 仅安装 VSCode 和 Postman

EOF
}

# 主函数
main() {
    echo "============================================"
    echo "       开发工具安装脚本"
    echo "============================================"
    echo ""
    
    # 检查 root 权限
    check_root
    
    # 解析命令行参数
    INSTALL_ALL=true
    INSTALL_VSCODE=false
    INSTALL_POSTMAN=false
    INSTALL_CONDA=false
    INSTALL_DOCKER=false
    INSTALL_NODEJS=false
    INSTALL_ZSH=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                INSTALL_ALL=true
                ;;
            --vscode)
                INSTALL_VSCODE=true
                INSTALL_ALL=false
                ;;
            --postman)
                INSTALL_POSTMAN=true
                INSTALL_ALL=false
                ;;
            --conda)
                INSTALL_CONDA=true
                INSTALL_ALL=false
                ;;
            --docker)
                INSTALL_DOCKER=true
                INSTALL_ALL=false
                ;;
            --nodejs)
                INSTALL_NODEJS=true
                INSTALL_ALL=false
                ;;
            --zsh)
                INSTALL_ZSH=true
                INSTALL_ALL=false
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    # 更新系统
    update_system
    
    # 安装基础依赖
    install_dependencies
    
    # 安装选中的工具
    if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_VSCODE" = true ]; then
        install_vscode
    fi
    
    if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_POSTMAN" = true ]; then
        install_postman
    fi
    
    if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_CONDA" = true ]; then
        install_conda
    fi
    
    if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_DOCKER" = true ]; then
        install_docker
        install_docker_compose
    fi
    
    if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_NODEJS" = true ]; then
        install_nodejs
    fi
    
    if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_ZSH" = true ]; then
        install_zsh
    fi
    
    echo ""
    echo "============================================"
    log_info "开发工具安装完成!"
    echo "============================================"
    echo ""
    echo "已安装的工具:"
    command -v code &> /dev/null && echo "  ✓ VSCode"
    command -v postman &> /dev/null && echo "  ✓ Postman"
    command -v conda &> /dev/null && echo "  ✓ Conda"
    command -v docker &> /dev/null && echo "  ✓ Docker"
    command -v node &> /dev/null && echo "  ✓ Node.js"
    command -v zsh &> /dev/null && echo "  ✓ Zsh"
    echo ""
}

# 运行主函数
main "$@"
