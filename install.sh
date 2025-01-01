#!/usr/bin/env bash
#
# 安装(下载) create_iam_user_for_bedrock.sh 的简易脚本
# 用法:
#   curl -sSL https://raw.githubusercontent.com/yordyi/AWSBedrock/main/install.sh | bash
#

set -e  # 脚本遇到错误时立即退出

# 你也可以在此加入对 curl、jq 等工具是否安装的检测:
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is not installed. Please install curl first."
  exit 1
fi

echo "==> 开始下载 create_iam_user_for_bedrock.sh ..."
# 从 main 分支直接下载脚本(假设脚本名相同, 并已push到 main 分支)
curl -sSLo create_iam_user_for_bedrock.sh \
  "https://raw.githubusercontent.com/yordyi/AWSBedrock/main/create_iam_user_for_bedrock.sh"

# 赋予执行权限
chmod +x create_iam_user_for_bedrock.sh

echo "==> 下载完成. 现在可以执行如下命令创建IAM用户:"
echo "    ./create_iam_user_for_bedrock.sh"
echo
echo "脚本默认依赖 'jq' 来解析 JSON, 如果尚未安装请先行安装."
echo "  macOS:  brew install jq"
echo "  Linux:  sudo apt-get install jq (Debian/Ubuntu) 或 sudo yum install jq (CentOS/RHEL)"
echo
echo "使用说明: 执行脚本后, 会提示输入具有IAM管理权限的Access Key和Secret Key, 并自动创建随机用户名的IAM用户."
echo "创建完成后会显示新用户的 Access Key / Secret Key, 以及已附加的 AmazonBedrockFullAccess 策略."
