#!/usr/bin/env bash
#
# create_iam_user_for_bedrock.sh
#
# 1. 运行脚本后，先提示你输入一对Access Key(上级账号/Root/有IAM管理权限的IAM用户)
# 2. 脚本自动创建一个临时Profile(temp-root-profile)，并用此Profile创建新IAM用户
# 3. 新用户的名称按照一定规则生成: bedrock-invoke-user-<时间戳>-<随机四位数>
# 4. 为新用户附加 AmazonBedrockFullAccess，并创建一对新的Access Key(输出在终端)
#
# 注意：AWS不支持"账号邮箱+密码"的方式直接在CLI登录，所以必须提供Access Key + Secret Key。
#       请务必保管好拥有IAM管理权限的密钥信息，谨慎使用Root账号。

set -e  # 遇到错误时立即退出脚本

#######################################
# 0. 脚本开头，提示输入上级账号的 Access Key/Secret Key
#######################################
echo "本脚本将创建一个新IAM用户，并分配Bedrock权限。"
echo "请先输入(拥有足够IAM管理权限的)账号的Access Key/Secret Key："
read -p "Enter your AWS Access Key ID: " ROOT_AWS_ACCESS_KEY_ID
# -s 表示隐藏输入
read -s -p "Enter your AWS Secret Access Key: " ROOT_AWS_SECRET_ACCESS_KEY
echo  # 换行

# 可在此处可选地让用户输入想要操作的AWS Region
AWS_REGION="us-east-1"  # 默认使用us-east-1，如果需要改，请自行修改

#######################################
# 1. 自动生成IAM用户名: bedrock-invoke-user-<timestamp>-<random4>
#######################################
TIMESTAMP=$(date +%Y%m%d%H%M%S)        # 获取当前时间戳，如20250101123045
RANDOM_4=$(printf "%04d" $((RANDOM % 10000)))  # 生成0-9999的随机数并格式化为4位
IAM_USER_NAME="bedrock-invoke-user-${TIMESTAMP}-${RANDOM_4}"

#######################################
# 2. 需要附加的策略 (此处为Bedrock完整权限)
#######################################
BEDROCK_POLICY_ARN="arn:aws:iam::aws:policy/AmazonBedrockFullAccess"

#######################################
# 3. 配置一个临时Profile来使用输入的Key
#######################################
TEMP_PROFILE_NAME="temp-root-profile"

echo "==> 配置临时AWS CLI Profile: $TEMP_PROFILE_NAME"
aws configure set aws_access_key_id "$ROOT_AWS_ACCESS_KEY_ID" --profile $TEMP_PROFILE_NAME
aws configure set aws_secret_access_key "$ROOT_AWS_SECRET_ACCESS_KEY" --profile $TEMP_PROFILE_NAME
aws configure set region "$AWS_REGION" --profile $TEMP_PROFILE_NAME

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
echo "==> 为用户 $IAM_USER_NAME 附加策略: $BEDROCK_POLICY_ARN"
aws iam attach-user-policy \
  --user-name "$IAM_USER_NAME" \
  --policy-arn "$BEDROCK_POLICY_ARN" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION"

#######################################
# 6. 创建访问密钥 (Access Key / Secret Key) 并解析输出
#######################################
echo "==> 为用户 $IAM_USER_NAME 创建访问密钥..."
CREATED_KEYS_JSON=$(aws iam create-access-key \
  --user-name "$IAM_USER_NAME" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION")

# 如需用到jq来解析JSON，请确保已安装jq。若没有可注释或改用其他解析方式。
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
echo "注意：Secret Access Key 只在此时显示一次，请妥善保存！"
echo "================================================"

#######################################
# 8. 可选：清理临时Profile（如不想保留）
#######################################
# 如果想在脚本结束后删除上述临时Profile，以防泄露上级账号信息：
# aws configure set aws_access_key_id "" --profile $TEMP_PROFILE_NAME
# aws configure set aws_secret_access_key "" --profile $TEMP_PROFILE_NAME
# aws configure set region "" --profile $TEMP_PROFILE_NAME
# echo "已清空并删除临时Profile: $TEMP_PROFILE_NAME"
