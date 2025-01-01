#!/usr/bin/env bash

# 设置错误时退出
set -e

echo "开始下载AWS Bedrock IAM用户创建脚本..."

# 下载主脚本
curl -O https://raw.githubusercontent.com/yordyi/AWSBedrock/main/create_iam_user_for_bedrock.sh

# 添加执行权限
chmod +x create_iam_user_for_bedrock.sh

echo "脚本下载完成并已添加执行权限"
echo "正在启动脚本..."
echo "----------------------------------------"

# 直接运行主脚本
./create_iam_user_for_bedrock.sh
