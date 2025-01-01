#!/usr/bin/env bash
#
# create_iam_user_for_bedrock.sh
#
# 用法:
#   直接执行:
#     curl -sSL https://raw.githubusercontent.com/yordyi/AWSBedrock/main/create_iam_user_for_bedrock.sh | bash
#
# 脚本功能:
# 1. 在执行时提示输入一个可创建IAM用户的 Access Key/Secret Key
# 2. 自动创建新的 IAM 用户(用户名随机带时间戳+随机数)
# 3. 给该用户附加 AmazonBedrockFullAccess 策略
# 4. 生成并输出新的 Access Key / Secret Key
#
# 注意:
# - 建议使用具备IAM管理权限的普通IAM用户, 而非Root账号.
# - 脚本依赖aws-cli和jq, 请提前安装.
# - 强烈不建议在生产环境长期使用Root权限Key.

set -e  # 一旦脚本出错即退出

#######################################
# 0. 检查依赖
#######################################
if ! command -v aws >/dev/null 2>&1; then
  echo "错误: 未检测到 aws CLI，请先安装 aws-cli。"
  echo "参考: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "警告: 未检测到 jq，脚本将无法解析JSON输出。"
  echo "请先安装jq后再执行此脚本，比如: sudo apt-get install jq 或 brew install jq"
  exit 1
fi

#######################################
# 1. 提示输入上级账号(拥有IAM管理权限)的Access Key/Secret Key
#######################################
echo "本脚本将创建一个新的IAM用户(并分配AmazonBedrockFullAccess)。"
echo "请先输入(拥有足够IAM管理权限的)账号的Access Key/Secret Key："
read -p "Enter your AWS Access Key ID: " ROOT_AWS_ACCESS_KEY_ID
# -s 表示隐藏输入
read -s -p "Enter your AWS Secret Access Key: " ROOT_AWS_SECRET_ACCESS_KEY
echo  # 空行换行

# 可以让用户选择 Region, 默认 us-east-1
AWS_REGION="us-east-1"

#######################################
# 2. 随机生成新IAM用户名
#######################################
TIMESTAMP=$(date +%Y%m%d%H%M%S)        
RANDOM_4=$(printf "%04d" $((RANDOM % 10000))) 
IAM_USER_NAME="bedrock-invoke-user-${TIMESTAMP}-${RANDOM_4}"

#######################################
# 3. 创建临时Profile
#######################################
TEMP_PROFILE_NAME="temp-root-profile-$$"  # $$是当前进程ID, 以防冲突

echo "配置临时AWS CLI Profile: $TEMP_PROFILE_NAME"
aws configure set aws_access_key_id "$ROOT_AWS_ACCESS_KEY_ID" --profile "$TEMP_PROFILE_NAME"
aws configure set aws_secret_access_key "$ROOT_AWS_SECRET_ACCESS_KEY" --profile "$TEMP_PROFILE_NAME"
aws configure set region "$AWS_REGION" --profile "$TEMP_PROFILE_NAME"

#######################################
# 4. 创建新IAM用户
#######################################
echo "==> 创建IAM用户: $IAM_USER_NAME"
aws iam create-user \
  --user-name "$IAM_USER_NAME" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION" || {
    echo "创建用户失败，可能已存在同名用户。请检查后重试。"
    exit 1
  }

#######################################
# 5. 附加AmazonBedrockFullAccess策略
#######################################
BEDROCK_POLICY_ARN="arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
echo "==> 为用户 $IAM_USER_NAME 附加策略: $BEDROCK_POLICY_ARN"
aws iam attach-user-policy \
  --user-name "$IAM_USER_NAME" \
  --policy-arn "$BEDROCK_POLICY_ARN" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION"

#######################################
# 6. 创建访问密钥，并解析输出
#######################################
echo "==> 为用户 $IAM_USER_NAME 创建访问密钥..."
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
echo "IAM 用户名:          $IAM_USER_NAME"
echo "Access Key ID:       $AWS_ACCESS_KEY_ID_NEW"
echo "Secret Access Key:   $AWS_SECRET_ACCESS_KEY_NEW"
echo "附加权限策略:        $BEDROCK_POLICY_ARN"
echo "所在Region:          $AWS_REGION"
echo
echo "注意：Secret Access Key 只在此时显示一次，请务必妥善保存！"
echo "================================================"

#######################################
# 8. 清理临时Profile
#######################################
aws configure set aws_access_key_id "" --profile "$TEMP_PROFILE_NAME"
aws configure set aws_secret_access_key "" --profile "$TEMP_PROFILE_NAME"
aws configure set region "" --profile "$TEMP_PROFILE_NAME"
# 或者可以使用 aws configure remove 命令(较新版本CLI支持):
# aws configure remove --profile "$TEMP_PROFILE_NAME"
echo "已删除临时Profile: $TEMP_PROFILE_NAME"
