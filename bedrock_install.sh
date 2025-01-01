#!/usr/bin/env bash
#
# bedrock_install.sh
# 用于简化命令行，让用户只用执行一次短命令。
# 在此脚本里，可以固定一些默认参数(如user-prefix、region等)。

# 你可以把默认值写死，也可以给用户二次覆盖的机会。
DEFAULT_REGION="us-east-1"
DEFAULT_USER_PREFIX="bedrock-user"

# 从 GitHub 下载主脚本(功能更全)
# 并使用你想要的默认参数
bash <(curl -sSL https://raw.githubusercontent.com/yordyi/AWSBedrock/main/create_iam_user_for_bedrock_ec2_quotas_minimal.sh) \
  --region="$DEFAULT_REGION" \
  --user-prefix="$DEFAULT_USER_PREFIX"
