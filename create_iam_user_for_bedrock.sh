#!/usr/bin/env bash
#
# create_iam_user_for_bedrock.sh
# 1. 运行脚本后，会提示你输入（拥有 IAM 管理权限的）Access Key/Secret Key
# 2. 脚本自动配置一个临时AWS CLI Profile: temp-root-profile
# 3. 用该Profile创建新的IAM用户，并附加AmazonBedrockFullAccess策略
# 4. 输出新用户的Access Key/Secret Key

set -e  # 遇到错误时立即退出脚本

#######################################
# 0. 脚本开头，提示输入上级账号的Access Key/Secret Key
#######################################
echo "本脚本将创建一个新IAM用户并分配Bedrock权限。"
echo "请先输入具有足够权限(可管理IAM)的账号的Access Key/Secret Key："
read -p "Enter your AWS Access Key ID: " ROOT_AWS_ACCESS_KEY_ID
# -s 表示隐藏输入
read -s -p "Enter your AWS Secret Access Key: " ROOT_AWS_SECRET_ACCESS_KEY
echo  # 换行

# 你也可以在此处可选地让用户输入想要操作的AWS Region：
AWS_REGION="us-east-1"  # 默认使用us-east-1，如果需要改，请自行修改

#######################################
# 1. 定义脚本中将要创建的IAM用户信息
#######################################
# 生成随机且有规律的用户名
RANDOM_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
IAM_USER_NAME="bedrock-user-${RANDOM_SUFFIX}"  # 新建的IAM用户名
BEDROCK_POLICY_ARN="arn:aws:iam::aws:policy/AmazonBedrockFullAccess"

#######################################
# 2. 配置一个临时Profile来使用输入的Key
#######################################
TEMP_PROFILE_NAME="temp-root-profile"

echo "==> 配置临时AWS CLI Profile: $TEMP_PROFILE_NAME"
aws configure set aws_access_key_id "$ROOT_AWS_ACCESS_KEY_ID" --profile $TEMP_PROFILE_NAME
aws configure set aws_secret_access_key "$ROOT_AWS_SECRET_ACCESS_KEY" --profile $TEMP_PROFILE_NAME
aws configure set region $AWS_REGION --profile $TEMP_PROFILE_NAME

#######################################
# 3. 验证AWS凭证
#######################################
echo "==> 验证AWS凭证"
if ! aws sts get-caller-identity --profile "$TEMP_PROFILE_NAME" &> /dev/null; then
    echo "错误：AWS凭证无效或没有足够的权限。请检查您的Access Key和Secret Key，确保它们是正确的且具有足够的权限。"
    exit 1
fi
echo "AWS凭证验证成功。"

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
# 4. 附加AmazonBedrockFullAccess策略
#######################################
echo "==> 为用户 $IAM_USER_NAME 附加策略: $BEDROCK_POLICY_ARN"
aws iam attach-user-policy \
  --user-name "$IAM_USER_NAME" \
  --policy-arn "$BEDROCK_POLICY_ARN" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION"

#######################################
# 5. 创建访问密钥 (Access Key / Secret Key) 并解析输出
#######################################
echo "==> 为用户 $IAM_USER_NAME 创建访问密钥..."
CREATED_KEYS_JSON=$(aws iam create-access-key \
  --user-name "$IAM_USER_NAME" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION")

# 如需用到jq来解析JSON，请确保已安装jq。若没有则需注释掉或换其他解析方式
AWS_ACCESS_KEY_ID=$(echo "$CREATED_KEYS_JSON" | jq -r '.AccessKey.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo "$CREATED_KEYS_JSON" | jq -r '.AccessKey.SecretAccessKey')

#######################################
# 6. 输出结果
#######################################
echo
echo "================== 创建完成 =================="
echo "IAM 用户名:          $IAM_USER_NAME"
echo "Access Key ID:       $AWS_ACCESS_KEY_ID"
echo "Secret Access Key:   $AWS_SECRET_ACCESS_KEY"
echo "附加权限策略:       $BEDROCK_POLICY_ARN"
echo "所在Region:          $AWS_REGION"
echo
echo "注意：Secret Access Key 只在此时显示一次，请妥善保存！"
echo "================================================"

#######################################
# 7. 可选：清理临时Profile（如果你不想保留）
#######################################
# 如果你想在脚本结束后删除上述临时Profile的配置，可以执行：
# aws configure set aws_access_key_id "" --profile $TEMP_PROFILE_NAME
# aws configure set aws_secret_access_key "" --profile $TEMP_PROFILE_NAME
# echo "已清空临时Profile: $TEMP_PROFILE_NAME (可选择保留也可删除)"
