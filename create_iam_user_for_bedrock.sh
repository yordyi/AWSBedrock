#!/usr/bin/env bash
#
# create_iam_user_for_bedrock.sh
#
# 用法(一行命令):
#   curl -sSL https://raw.githubusercontent.com/yordyi/AWSBedrock/main/create_iam_user_for_bedrock.sh | bash
#
# 功能:
# 1. 检查本机是否安装 aws-cli 和 jq。
# 2. 与终端进行交互：提示输入(拥有IAM管理权限的) Access Key ID 和 Secret Access Key。
#    -- 使用 /dev/tty 确保 read 从终端读入，而不是被 pipe 流吞掉。
# 3. 自动生成随机 IAM 用户名(时间戳+四位随机数)，创建并附加 AmazonBedrockFullAccess。
# 4. 输出新建用户的 Access Key / Secret Key (只显示一次)。
# 5. 清理临时Profile，以免泄露上级账号密钥。
#
# 注意:
# - 不要长期用 Root 账号，最好用一个具备 IAM 管理权限的普通 IAM 用户来执行。
# - 若要调用特定模型(例如Claude 3.5 Sonnet)仍需要AWS那边对账号开通白名单，否则可能403/400。
# - 生产环境最好使用更精细的权限策略，而不是Full Access。

set -e  # 任何命令出错立即退出

#######################################
# 0. 检查依赖
#######################################
if ! command -v aws >/dev/null 2>&1; then
  echo "错误: 未检测到 aws CLI，请先安装 aws-cli。"
  echo "参考: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "错误: 未检测到 jq，脚本将无法解析 JSON 输出。"
  echo "请先安装 jq 后再执行此脚本，比如: sudo apt-get install jq 或 brew install jq"
  exit 1
fi

#######################################
# 1. 提示输入上级账号(拥有IAM管理权限)的 Access Key / Secret Key
#    使用 /dev/tty 确保能在 "curl | bash" 模式下仍然与终端交互
#######################################
echo "本脚本将创建一个新的 IAM 用户，并分配 AmazonBedrockFullAccess 权限。"
echo "请在提示后输入(拥有足够 IAM 管理权限的)账号的 Access Key / Secret Key。"
echo

# 读 Access Key ID
read -r -p ">>> Enter your AWS Access Key ID: " ROOT_AWS_ACCESS_KEY_ID < /dev/tty
if [ -z "$ROOT_AWS_ACCESS_KEY_ID" ]; then
  echo "错误: 未输入 Access Key ID."
  exit 1
fi

# 读 Secret Access Key (隐藏输入)
read -r -s -p ">>> Enter your AWS Secret Access Key: " ROOT_AWS_SECRET_ACCESS_KEY < /dev/tty
echo
if [ -z "$ROOT_AWS_SECRET_ACCESS_KEY" ]; then
  echo "错误: 未输入 Secret Access Key."
  exit 1
fi

# 可以加一个Region选择，这里固定为us-east-1
AWS_REGION="us-east-1"

#######################################
# 2. 生成随机 IAM 用户名
#######################################
TIMESTAMP=$(date +%Y%m%d%H%M%S)
RANDOM_4=$(printf "%04d" $((RANDOM % 10000)))
IAM_USER_NAME="bedrock-invoke-user-${TIMESTAMP}-${RANDOM_4}"

#######################################
# 3. 使用一个临时 Profile
#######################################
TEMP_PROFILE_NAME="temp-root-profile-$$"

echo
echo "==> 配置临时AWS CLI Profile: $TEMP_PROFILE_NAME"
aws configure set aws_access_key_id "$ROOT_AWS_ACCESS_KEY_ID"     --profile "$TEMP_PROFILE_NAME"
aws configure set aws_secret_access_key "$ROOT_AWS_SECRET_ACCESS_KEY" --profile "$TEMP_PROFILE_NAME"
aws configure set region "$AWS_REGION"                            --profile "$TEMP_PROFILE_NAME"

#######################################
# 4. 创建新 IAM 用户
#######################################
echo "==> 创建 IAM 用户: $IAM_USER_NAME"
aws iam create-user \
  --user-name "$IAM_USER_NAME" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION" || {
    echo
    echo "创建用户失败，可能已存在同名用户。请检查后重试。"
    exit 1
  }

#######################################
# 5. 附加 AmazonBedrockFullAccess
#######################################
BEDROCK_POLICY_ARN="arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
echo "==> 为用户 $IAM_USER_NAME 附加策略: $BEDROCK_POLICY_ARN"
aws iam attach-user-policy \
  --user-name "$IAM_USER_NAME" \
  --policy-arn "$BEDROCK_POLICY_ARN" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION"

#######################################
# 6. 创建访问密钥并解析输出
#######################################
echo "==> 为用户 $IAM_USER_NAME 创建访问密钥(Access Key / Secret Key)..."
CREATED_KEYS_JSON=$(aws iam create-access-key \
  --user-name "$IAM_USER_NAME" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION")

AWS_ACCESS_KEY_ID_NEW=$(echo "$CREATED_KEYS_JSON" | jq -r '.AccessKey.AccessKeyId')
AWS_SECRET_ACCESS_KEY_NEW=$(echo "$CREATED_KEYS_JSON" | jq -r '.AccessKey.SecretAccessKey')

#######################################
# 7. 输出结果
#######################################
echo
echo "================== 创建完成 =================="
echo "IAM 用户名:         $IAM_USER_NAME"
echo "Access Key ID:      $AWS_ACCESS_KEY_ID_NEW"
echo "Secret Access Key:  $AWS_SECRET_ACCESS_KEY_NEW"
echo "附加权限策略:       $BEDROCK_POLICY_ARN"
echo "所在Region:         $AWS_REGION"
echo
echo "注意：Secret Access Key 只在此时显示一次，请务必妥善保存！"
echo "================================================"

#######################################
# 8. 清理临时Profile
#######################################
aws configure set aws_access_key_id "" --profile "$TEMP_PROFILE_NAME"       >/dev/null 2>&1
aws configure set aws_secret_access_key "" --profile "$TEMP_PROFILE_NAME"   >/dev/null 2>&1
aws configure set region "" --profile "$TEMP_PROFILE_NAME"                  >/dev/null 2>&1

echo
echo "已删除临时Profile: $TEMP_PROFILE_NAME"
echo "脚本执行完毕。"
