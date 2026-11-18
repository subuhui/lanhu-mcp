@echo off
chcp 65001 >nul
REM 蓝湖 MCP Server - 超级简单安装脚本 (Windows)
REM 专为小白用户设计，交互式引导安装

setlocal enabledelayedexpansion
cd /d "%~dp0"

REM 国内镜像优先；用户显式指定的下载源保持权威。
set "CUSTOM_PIP_INDEX_URL=%PIP_INDEX_URL%"
set "CUSTOM_PLAYWRIGHT_DOWNLOAD_HOST=%PLAYWRIGHT_DOWNLOAD_HOST%"
set "CUSTOM_PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST=%PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST%"
set "PLAYWRIGHT_MIRROR=https://cdn.npmmirror.com/binaries/playwright"
set "PLAYWRIGHT_CHROMIUM_MIRROR=https://cdn.npmmirror.com/binaries/chrome-for-testing"

cls

echo.
echo ╔═══════════════════════════════════════════════════╗
echo ║                                                   ║
echo ║     🎨 蓝湖 MCP Server - 一键安装程序            ║
echo ║                                                   ║
echo ║     让 AI 助手共享团队知识，打破 AI IDE 孤岛     ║
echo ║                                                   ║
echo ╚═══════════════════════════════════════════════════╝
echo.
echo 欢迎！这个脚本会帮你自动完成所有安装步骤
echo 预计耗时：3-5 分钟
echo.
echo 按 Enter 开始安装，或按 Ctrl+C 取消
if not defined LANHU_INSTALL_NONINTERACTIVE pause >nul

REM ============================================
REM 步骤 1: 环境检查
REM ============================================

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 📦 步骤 1/5: 检查系统环境
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

REM 检查 Python 版本
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 未检测到 Python
    echo 请从 https://www.python.org/downloads/ 安装 Python 3.10 或更高版本
    echo 安装时请勾选 "Add Python to PATH"
    if not defined LANHU_INSTALL_NONINTERACTIVE pause
    exit /b 1
)

set "PYTHON_MAJOR="
set "PYTHON_MINOR="
for /f "tokens=1,2 delims=." %%A in ('python -c "import sys; print(str(sys.version_info.major) + '.' + str(sys.version_info.minor))" 2^>nul') do (
    set "PYTHON_MAJOR=%%A"
    set "PYTHON_MINOR=%%B"
)
set "PYTHON_OK=1"
if not defined PYTHON_MAJOR set "PYTHON_OK="
if defined PYTHON_MAJOR if !PYTHON_MAJOR! LSS 3 set "PYTHON_OK="
if defined PYTHON_MAJOR if !PYTHON_MAJOR! EQU 3 if !PYTHON_MINOR! LSS 10 set "PYTHON_OK="
if not defined PYTHON_OK (
    for /f "tokens=2" %%V in ('python --version 2^>^&1') do set "PYTHON_VERSION=%%V"
    echo [ERROR] 需要 Python 3.10 或更高版本，当前版本：!PYTHON_VERSION!
    echo 请从 https://www.python.org/downloads/ 安装新版 Python 后重新运行
    if not defined LANHU_INSTALL_NONINTERACTIVE pause
    exit /b 1
)

for /f "tokens=2" %%V in ('python --version') do set "PYTHON_VERSION=%%V"
echo [OK] Python !PYTHON_VERSION!
python -m pip --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 当前 Python 没有可用的 pip
    if not defined LANHU_INSTALL_NONINTERACTIVE pause
    exit /b 1
)

echo.
echo 🎉 环境检查通过！
timeout /t 1 /nobreak >nul

REM ============================================
REM 步骤 2: 安装依赖
REM ============================================

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 📥 步骤 2/5: 安装依赖包
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

REM 创建虚拟环境
if not exist "venv" (
    echo 正在创建 Python 虚拟环境...
    python -m venv venv
    echo ✅ 虚拟环境创建完成
) else (
    echo ✅ 虚拟环境已存在
)
if not exist "venv\Scripts\python.exe" (
    echo [ERROR] venv 目录不是可用的 Python 虚拟环境
    echo 请删除 venv 目录后重新运行本脚本
    if not defined LANHU_INSTALL_NONINTERACTIVE pause
    exit /b 1
)
set "VENV_PYTHON_MAJOR="
set "VENV_PYTHON_MINOR="
for /f "tokens=1,2 delims=." %%A in ('venv\Scripts\python.exe -c "import sys; print(str(sys.version_info.major) + '.' + str(sys.version_info.minor))" 2^>nul') do (
    set "VENV_PYTHON_MAJOR=%%A"
    set "VENV_PYTHON_MINOR=%%B"
)
set "VENV_PYTHON_OK=1"
if not defined VENV_PYTHON_MAJOR set "VENV_PYTHON_OK="
if defined VENV_PYTHON_MAJOR if !VENV_PYTHON_MAJOR! LSS 3 set "VENV_PYTHON_OK="
if defined VENV_PYTHON_MAJOR if !VENV_PYTHON_MAJOR! EQU 3 if !VENV_PYTHON_MINOR! LSS 10 set "VENV_PYTHON_OK="
if not defined VENV_PYTHON_OK (
    echo [ERROR] 现有 venv 的 Python 版本低于 3.10
    echo 请删除 venv 目录后重新运行本脚本
    if not defined LANHU_INSTALL_NONINTERACTIVE pause
    exit /b 1
)

REM 安装项目及依赖
echo 正在安装项目及依赖...
echo （这可能需要 1-2 分钟，请耐心等待）
set "INSTALL_OK="
if defined CUSTOM_PIP_INDEX_URL (
    call :install_project "!CUSTOM_PIP_INDEX_URL!"
    if not errorlevel 1 set "INSTALL_OK=1"
) else (
    call :install_project "https://mirrors.aliyun.com/pypi/simple"
    if not errorlevel 1 set "INSTALL_OK=1"
    if not defined INSTALL_OK call :install_project "https://pypi.tuna.tsinghua.edu.cn/simple"
    if not errorlevel 1 set "INSTALL_OK=1"
    if not defined INSTALL_OK call :install_project "https://pypi.org/simple"
    if not errorlevel 1 set "INSTALL_OK=1"
)
if not defined INSTALL_OK (
    echo [ERROR] 项目依赖下载失败
    echo 已尝试可用的国内镜像与备用源，请检查网络或代理后重试
    echo 如需固定使用自定义 PyPI 镜像，可先设置 PIP_INDEX_URL
    if not defined LANHU_INSTALL_NONINTERACTIVE pause
    exit /b 1
)
venv\Scripts\python.exe -m pip check

echo ✅ 依赖安装完成

REM 安装 Playwright 浏览器
if defined LANHU_SKIP_BROWSER_INSTALL (
    echo [INFO] 已按 LANHU_SKIP_BROWSER_INSTALL 跳过 Chromium 下载
) else (
    echo.
    echo 正在安装 Playwright 浏览器...
    echo （首次安装需要下载 Chromium，可能需要 1-2 分钟）
    call :install_browser
    if errorlevel 1 (
        echo [ERROR] Chromium 下载失败
        echo 请检查网络后重试，也可通过 PLAYWRIGHT_DOWNLOAD_HOST 指定其他镜像
        if not defined LANHU_INSTALL_NONINTERACTIVE pause
        exit /b 1
    )
)

echo.
echo 🎉 依赖安装完成！
timeout /t 1 /nobreak >nul

REM ============================================
REM 步骤 3: 配置蓝湖 Cookie
REM ============================================

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 🍪 步骤 3/5: 配置蓝湖 Cookie
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

REM 复制 .env.example 到 .env
if not exist ".env" (
    if exist ".env.example" (
        copy .env.example .env >nul
        echo ✅ 已创建 .env 配置文件
    ) else (
        echo ❌ 未找到 .env.example 文件
        if not defined LANHU_INSTALL_NONINTERACTIVE pause
        exit /b 1
    )
) else (
    echo ✅ .env 文件已存在
)

echo.
echo 这是唯一需要你手动操作的步骤，很简单！
echo.
echo 请按照以下步骤操作：
echo.
echo   1️⃣  在浏览器打开：https://lanhuapp.com 并登录
echo.
echo   2️⃣  按下键盘 F12 键
echo      会打开开发者工具
echo.
echo   3️⃣  点击顶部的 "Network"（网络）标签
echo.
echo   4️⃣  按 F5 刷新页面
echo.
echo   5️⃣  在左侧请求列表中点击 第一个请求
echo.
echo   6️⃣  右侧找到 "Request Headers" 部分
echo      找到 "Cookie:" 开头的那一行
echo.
echo   7️⃣  选中并复制 整个 Cookie 值
echo      （Cookie 很长，确保全部复制）
echo.
echo   8️⃣  用记事本打开当前目录下的 .env 文件
echo      找到 LANHU_COOKIE 这一行
echo      将 your_lanhu_cookie_here 替换为你复制的 Cookie
echo      注意：保留引号，只替换引号内的内容
echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

REM 尝试打开浏览器和文件
if defined LANHU_INSTALL_NONINTERACTIVE (
    set "OPEN_FILES=n"
) else (
    set /p OPEN_FILES="我可以帮你打开蓝湖网站和 .env 文件吗？(y/n) [y]: "
    if "!OPEN_FILES!"=="" set OPEN_FILES=y
)
if /i "!OPEN_FILES!"=="y" (
    start https://lanhuapp.com
    start notepad .env
    echo ✅ 已打开浏览器和 .env 文件
    echo.
)

echo 完成配置后，按 Enter 继续...
if not defined LANHU_INSTALL_NONINTERACTIVE pause >nul

REM 读取 .env 文件中的 Cookie
set LANHU_COOKIE=
for /f "tokens=1,* delims==" %%a in ('type .env ^| findstr /B "LANHU_COOKIE="') do (
    set "LANHU_COOKIE=%%b"
)

REM 移除引号
set LANHU_COOKIE=%LANHU_COOKIE:"=%

REM 验证 Cookie 不为空
if "!LANHU_COOKIE!"=="" (
    echo ❌ Cookie 未配置或配置不正确
    echo 请确保在 .env 文件中正确设置了 LANHU_COOKIE
    if not defined LANHU_INSTALL_NONINTERACTIVE pause
    exit /b 1
)

if "!LANHU_COOKIE!"=="your_lanhu_cookie_here" (
    echo ❌ Cookie 未修改，请在 .env 文件中设置正确的 Cookie
    if not defined LANHU_INSTALL_NONINTERACTIVE pause
    exit /b 1
)

REM 简单验证 Cookie 格式
echo !LANHU_COOKIE! | findstr /C:"session=" >nul
if errorlevel 1 (
    echo !LANHU_COOKIE! | findstr /C:"user_token=" >nul
    if errorlevel 1 (
        echo ⚠️  Cookie 格式可能不正确
        set /p CONTINUE_ANYWAY="确定要继续吗？(y/n) [n]: "
        if /i not "!CONTINUE_ANYWAY!"=="y" (
            echo 安装已取消
            if not defined LANHU_INSTALL_NONINTERACTIVE pause
            exit /b 1
        )
    )
)

echo.
echo ✅ Cookie 配置验证通过！
timeout /t 1 /nobreak >nul

REM ============================================
REM 步骤 4: 创建数据目录
REM ============================================

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 📁 步骤 4/5: 创建数据目录
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

REM 创建数据目录
if not exist "data" mkdir data
if not exist "logs" mkdir logs
echo ✅ 数据目录已创建

timeout /t 1 /nobreak >nul

REM ============================================
REM 步骤 5: 启动服务
REM ============================================

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 🚀 步骤 5/5: 启动服务
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

if defined LANHU_INSTALL_NONINTERACTIVE (
    set "START_NOW=n"
) else (
    set /p START_NOW="是否现在启动服务？(y/n) [y]: "
    if "!START_NOW!"=="" set START_NOW=y
)

if /i "!START_NOW!"=="y" (
    echo.
    echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    echo 🎉 安装成功！服务正在启动...
    echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    echo.
    echo 下一步：在 Cursor 中配置 MCP
    echo.
    echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    call scripts\print-mcp-config.bat
    echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    echo.
    echo 配置方法：
    echo   1. 打开 Cursor
    echo   2. 按 Ctrl+Shift+P
    echo   3. 输入 'MCP' 找到 MCP 配置
    echo   4. 粘贴上面的配置
    echo.
    echo 按 Ctrl+C 可以停止服务器
    echo.
    echo 正在启动服务器...
    echo.
    
    REM 运行服务器
    venv\Scripts\lanhu-mcp.exe --transport http
) else (
    echo.
    echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    echo 🎉 安装成功！
    echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    echo.
    echo 稍后运行服务器，请执行：
    echo   venv\Scripts\lanhu-mcp.exe --transport http
    echo.
    if not defined LANHU_INSTALL_NONINTERACTIVE pause
)

exit /b 0

:install_browser
if defined CUSTOM_PLAYWRIGHT_DOWNLOAD_HOST goto install_browser_custom
if defined CUSTOM_PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST goto install_browser_custom
set "PLAYWRIGHT_DOWNLOAD_HOST=%PLAYWRIGHT_MIRROR%"
set "PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST=%PLAYWRIGHT_CHROMIUM_MIRROR%"
echo 正在使用国内 Playwright 镜像（Chrome for Testing 专用路径）
venv\Scripts\python.exe -m playwright install chromium
if not errorlevel 1 exit /b 0
echo [WARN] 新版国内镜像路径不可用，尝试兼容旧版 Playwright 镜像...
set "PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST="
venv\Scripts\python.exe -m playwright install chromium
if not errorlevel 1 exit /b 0
echo [WARN] 国内镜像均不可用，自动回退 Playwright 官方 CDN...
set "PLAYWRIGHT_DOWNLOAD_HOST="
set "PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST="
venv\Scripts\python.exe -m playwright install chromium
if errorlevel 1 exit /b 1
exit /b 0

:install_browser_custom
set "PLAYWRIGHT_DOWNLOAD_HOST=%CUSTOM_PLAYWRIGHT_DOWNLOAD_HOST%"
set "PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST=%CUSTOM_PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST%"
echo 正在使用用户指定的 Playwright 下载源
venv\Scripts\python.exe -m playwright install chromium
if errorlevel 1 exit /b 1
exit /b 0

:install_project
set "PIP_INDEX_URL=%~1"
echo 正在使用 Python 包源：%PIP_INDEX_URL%
venv\Scripts\python.exe -m pip install --timeout 60 --retries 5 -e . -q
if errorlevel 1 (
    echo [WARN] 当前包源不可用，尝试下一个...
    exit /b 1
)
exit /b 0
