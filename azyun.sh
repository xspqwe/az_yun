#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # 清除颜色

# 定义符号
CHECK_MARK="\xE2\x9C\x94"
CROSS_MARK="\xE2\x9C\x98"
ARROW="\xE2\x9E\xA4"

# 打印横幅
print_banner() {
    clear
echo -e "${BLUE}"
echo "┌──────────────────────────────────────┐"
echo "│        Azure 脚本—云AI科技工具       │"
echo "└──────────────────────────────────────┘"
echo -e "${NC}"
}

# 显示加载动画
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# 进度条函数
show_progress() {
    local duration=0.1
    local width=50
    local progress=0
    while [ $progress -le 100 ]; do
        local count=$(($width * $progress / 100))
        local spaces=$((width - count))
        
        echo -ne "\r["
        printf "%${count}s" | tr ' ' '#'
        printf "%${spaces}s" | tr ' ' '-'
        echo -ne "] ${progress}%"
        
        progress=$((progress + 2))
        sleep $duration
    done
    echo
}

# 主程序
main() {
    print_banner
    
    echo -e "${YELLOW}${ARROW} 欢迎使用 Azure 脚本——云AI科技${NC}\n"
    
    # 提示输入token
    echo -e "${BLUE}请输入您的 激活码:${NC}"
    echo -e "${YELLOW}(请输入正确的激活码)${NC}"
    read -r -p "> " token

    # 验证token格式
    if [[ ! $token =~ ^ghp_ ]]; then
        echo -e "\n${RED}${CROSS_MARK} 错误: 激活码格式无效${NC}"
        echo -e "${YELLOW}请输入正确的激活码${NC}"
        exit 1
    fi

    echo -e "\n${BLUE}正在验证 激活码...${NC}"
    progress_bar 0.03

    # 设置下载URL
    url="https://raw.githubusercontent.com/xspqwe/azure/main/azure.sh"
    
    echo -e "\n${YELLOW}正在下载脚本...${NC}"
    
    # 使用curl下载文件,带token验证
    if curl -H "Authorization: token $token" -L -o azure.sh "$url" 2>/dev/null; then
        echo -e "\n${GREEN}${CHECK_MARK} 文件下载成功${NC}"
        chmod +x azure.sh
        
        echo -e "\n${BLUE}准备执行脚本...${NC}"
        progress_bar 0.02
        
        echo -e "\n${GREEN}${CHECK_MARK} 开始执行 脚本主体${NC}\n"
        ./azure.sh
    else
        echo -e "\n${RED}${CROSS_MARK} 错误: 脚本激活失败${NC}"
        echo -e "${YELLOW}请检查以下可能的问题:${NC}"
        echo "1. 激活码 是否有效"
        echo "2. 网络连接是否正常"
        echo "3. 目标文件是否存在"
        exit 1
    fi
}

# 运行主程序
main
