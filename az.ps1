#!/bin/bash

# 设置变量
SCRIPT_URL="https://raw.githubusercontent.com/xspqwe/az_yun/main/azps.ps1"
LOCAL_SCRIPT="azps.ps1"

echo "开始下载PowerShell脚本..."

# 下载脚本
if command -v curl &> /dev/null; then
    curl -s -o "$LOCAL_SCRIPT" "$SCRIPT_URL"
    DOWNLOAD_STATUS=$?
elif command -v wget &> /dev/null; then
    wget -q -O "$LOCAL_SCRIPT" "$SCRIPT_URL"
    DOWNLOAD_STATUS=$?
else
    echo "错误: 需要curl或wget来下载脚本，但系统中都没有安装。"
    exit 1
fi

# 检查下载是否成功
if [ $DOWNLOAD_STATUS -ne 0 ]; then
    echo "错误: 脚本下载失败。请检查URL和网络连接。"
    exit 1
fi

echo "脚本下载成功。"

# 检查PowerShell是否安装
if command -v pwsh &> /dev/null; then
    echo "使用PowerShell Core (pwsh)运行脚本..."
    pwsh -File "$LOCAL_SCRIPT"
elif command -v powershell &> /dev/null; then
    echo "使用Windows PowerShell运行脚本..."
    powershell -File "$LOCAL_SCRIPT"
else
    echo "错误: 系统中未安装PowerShell。请安装PowerShell以运行此脚本。"
    echo "对于Linux系统，可以使用以下命令安装PowerShell Core:"
    echo "  - Debian/Ubuntu: sudo apt-get install -y powershell"
    echo "  - CentOS/RHEL: sudo yum install -y powershell"
    echo "  - Fedora: sudo dnf install -y powershell"
    exit 1
fi

echo "脚本执行完成。"
