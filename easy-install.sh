#!/bin/bash

# 蓝湖 MCP Server - 超级简单安装脚本
# 专为小白用户设计，交互式引导安装

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 始终以脚本所在仓库为工作目录，避免从其他目录调用时写错位置。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 国内镜像优先；用户显式指定的下载源保持权威。
CUSTOM_PIP_INDEX_URL="${PIP_INDEX_URL:-}"
CUSTOM_PLAYWRIGHT_DOWNLOAD_HOST="${PLAYWRIGHT_DOWNLOAD_HOST:-}"
CUSTOM_PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST="${PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST:-}"
PLAYWRIGHT_MIRROR="https://cdn.npmmirror.com/binaries/playwright"
PLAYWRIGHT_CHROMIUM_MIRROR="https://cdn.npmmirror.com/binaries/chrome-for-testing"

# 清屏失败不应中断无交互安装。
clear 2>/dev/null || true

echo -e "${BOLD}${BLUE}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║                                                   ║"
echo "║     🎨 蓝湖 MCP Server - 一键安装程序            ║"
echo "║                                                   ║"
echo "║     让 AI 助手共享团队知识，打破 AI IDE 孤岛     ║"
echo "║                                                   ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${GREEN}欢迎！这个脚本会帮你自动完成所有安装步骤${NC}"
echo -e "${GREEN}预计耗时：3-5 分钟${NC}"
echo ""
echo -e "按 ${BOLD}Enter${NC} 开始安装，或按 ${BOLD}Ctrl+C${NC} 取消"
read

# ============================================
# 步骤 1: 环境检查
# ============================================

echo ""
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}📦 步骤 1/5: 检查系统环境${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 检查 Python。macOS 仍可能自带 Python 3.9，因此必须校验实际版本。
echo -e "正在检查 Python..."
PYTHON_BIN=""
for candidate in python3 python python3.13 python3.12 python3.11 python3.10; do
    if command -v "$candidate" >/dev/null 2>&1 \
        && "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
        PYTHON_BIN=$(command -v "$candidate")
        break
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    DETECTED_VERSION="未检测到"
    if command -v python3 >/dev/null 2>&1; then
        DETECTED_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')
    fi
    echo -e "${RED}❌ 需要 Python 3.10 或更高版本，当前版本：${DETECTED_VERSION}${NC}"
    echo ""
    echo "请先安装新版 Python，然后重新运行本脚本："
    echo "  Mac: brew install python"
    echo "  Ubuntu: sudo apt install python3 python3-venv python3-pip"
    echo "  官网: https://www.python.org/downloads/"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_BIN -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')
echo -e "${GREEN}✅ Python $PYTHON_VERSION ($PYTHON_BIN)${NC}"

if ! "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
    echo -e "${RED}❌ 这个 Python 没有可用的 pip：$PYTHON_BIN${NC}"
    echo "请安装 pip 后重新运行本脚本。"
    exit 1
fi
echo -e "${GREEN}✅ pip 已安装${NC}"

# 检查 Git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}⚠️  未检测到 Git（可选）${NC}"
else
    echo -e "${GREEN}✅ Git 已安装${NC}"
fi

echo ""
echo -e "${GREEN}🎉 环境检查通过！${NC}"
sleep 1

# ============================================
# 步骤 2: 安装依赖
# ============================================

echo ""
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}📥 步骤 2/5: 安装依赖包${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 创建虚拟环境
if [ ! -d "venv" ]; then
    echo "正在创建 Python 虚拟环境..."
    "$PYTHON_BIN" -m venv venv
    echo -e "${GREEN}✅ 虚拟环境创建完成${NC}"
else
    echo -e "${GREEN}✅ 虚拟环境已存在${NC}"
fi

VENV_PYTHON="venv/bin/python"
if [ ! -x "$VENV_PYTHON" ]; then
    echo -e "${RED}❌ venv 目录不是可用的 Python 虚拟环境${NC}"
    echo "请删除 venv 目录后重新运行本脚本。"
    exit 1
fi
if ! "$VENV_PYTHON" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'; then
    VENV_VERSION=$($VENV_PYTHON -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')
    echo -e "${RED}❌ 现有 venv 使用 Python $VENV_VERSION，项目要求 Python 3.10+${NC}"
    echo "请删除 venv 目录后重新运行本脚本。"
    exit 1
fi

# 安装项目及依赖，确保 lanhu-mcp CLI 和 lanhu_design 包都可用。
echo "正在安装项目及依赖..."
echo -e "${YELLOW}（这可能需要 1-2 分钟，请耐心等待）${NC}"
install_project() {
    local indexes=()
    if [ -n "$CUSTOM_PIP_INDEX_URL" ]; then
        indexes=("$CUSTOM_PIP_INDEX_URL")
    else
        indexes=(
            "https://mirrors.aliyun.com/pypi/simple"
            "https://pypi.tuna.tsinghua.edu.cn/simple"
            "https://pypi.org/simple"
        )
    fi

    local index
    for index in "${indexes[@]}"; do
        echo "正在使用 Python 包源：$index"
        if PIP_INDEX_URL="$index" "$VENV_PYTHON" -m pip install --timeout 60 --retries 5 -e . -q; then
            export PIP_INDEX_URL="$index"
            return 0
        fi
        echo -e "${YELLOW:-}⚠️  当前包源不可用，尝试下一个...${NC:-}"
    done
    return 1
}

if ! install_project; then
    echo -e "${RED:-}❌ 项目依赖下载失败${NC:-}"
    echo "已尝试可用的国内镜像与备用源，请检查网络或代理后重试。"
    echo "如需固定使用自定义 PyPI 镜像，可先设置 PIP_INDEX_URL。"
    exit 1
fi
"$VENV_PYTHON" -m pip check

echo -e "${GREEN}✅ 依赖安装完成${NC}"

install_playwright_browser() {
    if [ -n "$CUSTOM_PLAYWRIGHT_DOWNLOAD_HOST" ] || [ -n "$CUSTOM_PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST" ]; then
        echo "正在使用用户指定的 Playwright 下载源"
        local custom_env=()
        [ -n "$CUSTOM_PLAYWRIGHT_DOWNLOAD_HOST" ] && custom_env+=("PLAYWRIGHT_DOWNLOAD_HOST=$CUSTOM_PLAYWRIGHT_DOWNLOAD_HOST")
        [ -n "$CUSTOM_PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST" ] && custom_env+=("PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST=$CUSTOM_PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST")
        env "${custom_env[@]}" "$VENV_PYTHON" -m playwright install chromium
        return
    fi

    echo "正在使用国内 Playwright 镜像（Chrome for Testing 专用路径）"
    if PLAYWRIGHT_DOWNLOAD_HOST="$PLAYWRIGHT_MIRROR" \
        PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST="$PLAYWRIGHT_CHROMIUM_MIRROR" \
        "$VENV_PYTHON" -m playwright install chromium; then
        return 0
    fi

    echo -e "${YELLOW:-}⚠️  新版国内镜像路径不可用，尝试兼容旧版 Playwright 镜像...${NC:-}"
    if env -u PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST \
        PLAYWRIGHT_DOWNLOAD_HOST="$PLAYWRIGHT_MIRROR" \
        "$VENV_PYTHON" -m playwright install chromium; then
        return 0
    fi

    echo -e "${YELLOW:-}⚠️  国内镜像均不可用，自动回退 Playwright 官方 CDN...${NC:-}"
    env -u PLAYWRIGHT_DOWNLOAD_HOST -u PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST \
        "$VENV_PYTHON" -m playwright install chromium
}
# 安装 Playwright 浏览器
echo ""
echo "正在安装 Playwright 浏览器..."
echo -e "${YELLOW}（首次安装需要下载 Chromium，可能需要 1-2 分钟）${NC}"
if ! install_playwright_browser; then
    echo "❌ Chromium 下载失败"
    echo "请检查网络后重试；也可通过 PLAYWRIGHT_DOWNLOAD_HOST 指定其他镜像。"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 依赖安装完成！${NC}"
sleep 1

# ============================================
# 步骤 3: 配置蓝湖 Cookie
# ============================================

echo ""
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}🍪 步骤 3/5: 配置蓝湖 Cookie${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 复制 .env.example 到 .env
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ 已创建 .env 配置文件${NC}"
    else
        echo -e "${RED}❌ 未找到 .env.example 文件${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ .env 文件已存在${NC}"
fi

echo ""
echo -e "${YELLOW}这是唯一需要你手动操作的步骤，很简单！${NC}"
echo ""
echo -e "${BOLD}请按照以下步骤操作：${NC}"
echo ""
echo -e "  1️⃣  在浏览器打开：${BOLD}${BLUE}https://lanhuapp.com${NC} 并登录"
echo ""
echo -e "  2️⃣  按下键盘 ${BOLD}F12${NC} 键（Mac 用户按 ${BOLD}Command+Option+I${NC}）"
echo "     会打开开发者工具"
echo ""
echo -e "  3️⃣  点击顶部的 ${BOLD}\"Network\"${NC}（网络）标签"
echo ""
echo -e "  4️⃣  按 ${BOLD}F5${NC} 刷新页面"
echo ""
echo -e "  5️⃣  在左侧请求列表中点击 ${BOLD}第一个请求${NC}"
echo ""
echo -e "  6️⃣  右侧找到 ${BOLD}\"Request Headers\"${NC} 部分"
echo "     找到 \"Cookie:\" 开头的那一行"
echo ""
echo -e "  7️⃣  ${BOLD}选中并复制${NC} 整个 Cookie 值"
echo "     （Cookie 很长，确保全部复制）"
echo ""
echo -e "  8️⃣  用文本编辑器打开当前目录下的 ${BOLD}.env${NC} 文件"
echo -e "     找到 ${BOLD}LANHU_COOKIE${NC} 这一行"
echo -e "     将 ${BOLD}your_lanhu_cookie_here${NC} 替换为你复制的 Cookie"
echo -e "     ${YELLOW}注意：保留引号，只替换引号内的内容${NC}"
echo ""
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 如果系统支持，尝试打开浏览器和文件
if command -v open &> /dev/null; then
    echo -e "我可以帮你打开蓝湖网站和 .env 文件吗？(y/n) [${BOLD}y${NC}]: "
    read -r open_files
    open_files=${open_files:-y}
    if [ "$open_files" = "y" ] || [ "$open_files" = "Y" ]; then
        open "https://lanhuapp.com" 2>/dev/null || true
        open -e ".env" 2>/dev/null || open ".env" 2>/dev/null || true
        echo -e "${GREEN}✅ 已打开浏览器和 .env 文件${NC}"
        echo ""
    fi
fi

echo -e "${BOLD}完成配置后，按 Enter 继续...${NC}"
read

# 读取 .env 文件中的 Cookie
if [ -f ".env" ]; then
    LANHU_COOKIE=$(grep "^LANHU_COOKIE=" .env | cut -d'"' -f2)
fi

# 验证 Cookie 不为空
if [ -z "$LANHU_COOKIE" ] || [ "$LANHU_COOKIE" = "your_lanhu_cookie_here" ]; then
    echo -e "${RED}❌ Cookie 未配置或配置不正确${NC}"
    echo -e "${YELLOW}请确保在 .env 文件中正确设置了 LANHU_COOKIE${NC}"
    exit 1
fi

# 简单验证 Cookie 格式
if [[ ! "$LANHU_COOKIE" =~ "session=" ]] && [[ ! "$LANHU_COOKIE" =~ "user_token=" ]]; then
    echo -e "${YELLOW}⚠️  Cookie 格式可能不正确${NC}"
    echo "确定要继续吗？(y/n) [n]: "
    read -r continue_anyway
    if [ "$continue_anyway" != "y" ] && [ "$continue_anyway" != "Y" ]; then
        echo "安装已取消"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✅ Cookie 配置验证通过！${NC}"
sleep 1

# ============================================
# 步骤 4: 创建数据目录
# ============================================

echo ""
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}📁 步骤 4/5: 创建数据目录${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 创建数据目录
mkdir -p data logs
echo -e "${GREEN}✅ 数据目录已创建${NC}"

sleep 1

# ============================================
# 步骤 5: 启动服务
# ============================================

echo ""
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}🚀 步骤 5/5: 启动服务${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}是否现在启动服务？(y/n) [${BOLD}y${NC}]: ${NC}"
read -r start_now
start_now=${start_now:-y}

if [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
    echo ""
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${GREEN}🎉 安装成功！服务正在启动...${NC}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BOLD}下一步：在 Cursor 中配置 MCP${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    bash scripts/print-mcp-config.sh
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BOLD}配置方法：${NC}"
    echo "  1. 打开 Cursor"
    echo "  2. 按 Command+Shift+P (Mac) 或 Ctrl+Shift+P (Windows)"
    echo "  3. 输入 'MCP' 找到 MCP 配置"
    echo "  4. 粘贴上面的配置"
    echo ""
    echo -e "按 ${BOLD}Ctrl+C${NC} 可以停止服务器"
    echo ""
    echo -e "${GREEN}正在启动服务器...${NC}"
    echo ""
    
    # 运行服务器
    ./venv/bin/lanhu-mcp --transport http
else
    echo ""
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${GREEN}🎉 安装成功！${NC}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "稍后运行服务器，请执行："
    echo -e "  ${BOLD}./venv/bin/lanhu-mcp --transport http${NC}"
    echo ""
fi

