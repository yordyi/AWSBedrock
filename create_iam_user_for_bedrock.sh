#!/usr/bin/env bash
#
# create_iam_user_for_bedrock_ec2_quotas.sh
#
# 功能：
#   1. 可通过命令行参数指定新建用户的前缀 (--user-prefix=xxx) 和 AWS Region (--region=xxx)。
#   2. 自动检查 (并尝试安装) aws-cli 和 jq。
#   3. 输入拥有IAM管理权限的 Access Key / Secret Key，自动创建随机用户名的 IAM 用户。
#   4. 为该用户附加:
#       - AmazonBedrockFullAccess
#       - AmazonEC2FullAccess
#       - ServiceQuotasFullAccess
#   5. 输出新用户的 Access Key / Secret Key，并提示安全注意事项。
#   6. 如果脚本中途失败，自动回滚删除已创建的用户，避免资源残留。
#
# 用法 (示例):
#   1)  bash <(curl -sSL https://raw.githubusercontent.com/yordyi/AWSBedrock/main/create_iam_user_for_bedrock_ec2_quotas.sh) \
#         --user-prefix=myproj-user --region=us-west-2
#
#   2)  先下载后执行:
#       curl -sSL https://raw.githubusercontent.com/yordyi/AWSBedrock/main/create_iam_user_for_bedrock_ec2_quotas.sh \
#         -o create_iam_user_for_bedrock_ec2_quotas.sh
#       chmod +x create_iam_user_for_bedrock_ec2_quotas.sh
#       ./create_iam_user_for_bedrock_ec2_quotas.sh --user-prefix=myproj-user --region=us-west-2
#
# 参数:
#   --help               显示帮助
#   --user-prefix=<val>  指定IAM用户名的前缀(默认: bedrock-invoke-user)
#   --region=<val>       指定AWS区域(默认: us-east-1)
#
# 注意:
#   - 脚本仍使用 FullAccess 策略, 权限很大, 请在生产环境慎用.
#   - 建议先安装Homebrew或准备好sudo权限, 以便自动安装缺失依赖.
#   - 脚本结束会有安全与生命周期的提示.

set -e  # 脚本任一命令出错即退出
set -u  # 使用未定义变量时退出

#######################################
# 0. 解析命令行参数
#######################################
USER_PREFIX="bedrock-invoke-user"
AWS_REGION="us-east-1"

for arg in "$@"; do
  case "$arg" in
    --help)
      echo "用法: $0 [--user-prefix=<prefix>] [--region=<aws-region>]"
      echo "  --user-prefix=STRING   新建用户名前缀(默认: $USER_PREFIX)"
      echo "  --region=STRING        AWS区域(默认: $AWS_REGION)"
      echo "示例:"
      echo "  $0 --user-prefix=dev-user --region=us-west-2"
      exit 0
      ;;
    --user-prefix=*)
      USER_PREFIX="${arg#*=}"
      ;;
    --region=*)
      AWS_REGION="${arg#*=}"
      ;;
    *)
      echo "未知参数: $arg"
      echo "可用参数: --help, --user-prefix=xxx, --region=xxx"
      exit 1
      ;;
  esac
done

#######################################
# 1. 自动检查并尝试安装依赖 aws-cli, jq
#######################################
check_or_install_deps() {
  local missing=""
  if ! command -v aws &>/dev/null; then
    missing="$missing awscli"
  fi
  if ! command -v jq &>/dev/null; then
    missing="$missing jq"
  fi

  # 如果没有缺失则直接返回
  if [ -z "$missing" ]; then
    return
  fi

  echo "检测到缺少依赖:$missing"
  # 判断系统环境, 简单示例: 如果是macOS, 尝试brew安装; 如果是Debian/Ubuntu, 尝试apt-get.
  # (这里只是演示, 并不保证适配所有发行版)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "在macOS环境下, 尝试使用 brew 安装: $missing"
    if command -v brew &>/dev/null; then
      for pkg in $missing; do
        brew install "$pkg"
      done
    else
      echo "未检测到 Homebrew, 请手动安装后重试: https://brew.sh/"
      exit 1
    fi
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # 假设是 Debian/Ubuntu
    if command -v apt-get &>/dev/null; then
      echo "在Debian/Ubuntu环境下, 尝试 sudo apt-get install -y$missing"
      sudo apt-get update
      for pkg in $missing; do
        sudo apt-get install -y "$pkg"
      done
    # 其他Linux发行版可以再判断 yum/dnf 等
    else
      echo "无法识别的Linux发行版, 请手动安装:$missing"
      exit 1
    fi
  else
    echo "无法自动安装依赖, 请手动安装:$missing"
    exit 1
  fi
}

check_or_install_deps

#######################################
# 2. 与终端交互: 输入上级账号的 Access Key / Secret Key
#######################################
echo "本脚本将创建一个新的 IAM 用户，并附加下列权限:"
echo "1) AmazonBedrockFullAccess"
echo "2) AmazonEC2FullAccess"
echo "3) ServiceQuotasFullAccess"
echo
echo "用户名前缀: $USER_PREFIX"
echo "Region: $AWS_REGION"
echo
echo "请在提示后输入(拥有足够IAM管理权限的)账号的 Access Key / Secret Key。"

exec 3</dev/tty
read -r -p ">>> Enter your AWS Access Key ID: " ROOT_AWS_ACCESS_KEY_ID <&3
if [ -z "$ROOT_AWS_ACCESS_KEY_ID" ]; then
  echo "错误: 未输入 Access Key ID."
  exit 1
fi

read -r -s -p ">>> Enter your AWS Secret Access Key: " ROOT_AWS_SECRET_ACCESS_KEY <&3
echo
if [ -z "$ROOT_AWS_SECRET_ACCESS_KEY" ]; then
  echo "错误: 未输入 Secret Access Key."
  exit 1
fi
exec 3<&-

#######################################
# 3. 生成随机 IAM 用户名
#######################################
TIMESTAMP=$(date +%Y%m%d%H%M%S)
RANDOM_4=$(printf "%04d" $((RANDOM % 10000)))
IAM_USER_NAME="${USER_PREFIX}-${TIMESTAMP}-${RANDOM_4}"

#######################################
# 4. 配置一个临时Profile
#######################################
TEMP_PROFILE_NAME="temp-root-profile-$$"
aws configure set aws_access_key_id "$ROOT_AWS_ACCESS_KEY_ID"       --profile "$TEMP_PROFILE_NAME"
aws configure set aws_secret_access_key "$ROOT_AWS_SECRET_ACCESS_KEY" --profile "$TEMP_PROFILE_NAME"
aws configure set region "$AWS_REGION"                              --profile "$TEMP_PROFILE_NAME"

#######################################
# 5. 失败时的清理(回滚)
#######################################
ROLLBACK_USER_CREATED="false"
function on_error() {
  local exit_code=$?
  if [[ "$ROLLBACK_USER_CREATED" == "true" ]]; then
    echo
    echo "脚本中途失败, 正在回滚: 删除已创建的用户: $IAM_USER_NAME"
    aws iam delete-user --user-name "$IAM_USER_NAME" --profile "$TEMP_PROFILE_NAME" --region "$AWS_REGION" || true
  fi
  exit $exit_code
}
trap on_error ERR

#######################################
# 6. 创建新 IAM 用户
#######################################
echo
echo "==> 创建 IAM 用户: $IAM_USER_NAME"
aws iam create-user \
  --user-name "$IAM_USER_NAME" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION"

ROLLBACK_USER_CREATED="true"

#######################################
# 7. 依次附加策略
#######################################
echo "==> 为用户 $IAM_USER_NAME 附加策略 AmazonBedrockFullAccess, AmazonEC2FullAccess, ServiceQuotasFullAccess"
aws iam attach-user-policy \
  --user-name "$IAM_USER_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonBedrockFullAccess" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION"

aws iam attach-user-policy \
  --user-name "$IAM_USER_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonEC2FullAccess" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION"

aws iam attach-user-policy \
  --user-name "$IAM_USER_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/ServiceQuotasFullAccess" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION"

#######################################
# 8. 创建访问密钥并解析输出
#######################################
echo "==> 为用户 $IAM_USER_NAME 创建访问密钥 (Access Key / Secret Key)..."
CREATED_KEYS_JSON=$(aws iam create-access-key \
  --user-name "$IAM_USER_NAME" \
  --profile "$TEMP_PROFILE_NAME" \
  --region "$AWS_REGION")

AWS_ACCESS_KEY_ID_NEW=$(echo "$CREATED_KEYS_JSON" | jq -r '.AccessKey.AccessKeyId')
AWS_SECRET_ACCESS_KEY_NEW=$(echo "$CREATED_KEYS_JSON" | jq -r '.AccessKey.SecretAccessKey')

#######################################
# 9. 输出结果 (提示安全注意)
#######################################
echo
echo "================== 创建完成 =================="
echo "IAM 用户名:         $IAM_USER_NAME"
echo "Access Key ID:      $AWS_ACCESS_KEY_ID_NEW"
echo "Secret Access Key:  $AWS_SECRET_ACCESS_KEY_NEW"
echo "附加策略:           AmazonBedrockFullAccess, AmazonEC2FullAccess, ServiceQuotasFullAccess"
echo "所在Region:         $AWS_REGION"
echo
echo "!!! 安全提醒："
echo "1) Secret Access Key 只在此时显示一次，请勿将其暴露到公共环境或版本库中。"
echo "2) 如需短期测试，请在用完后删除或禁用该用户，以减少安全风险。"
echo "================================================"

#######################################
# 10. 清理临时Profile
#######################################
aws configure set aws_access_key_id ""       --profile "$TEMP_PROFILE_NAME" >/dev/null 2>&1
aws configure set aws_secret_access_key ""   --profile "$TEMP_PROFILE_NAME" >/dev/null 2>&1
aws configure set region ""                  --profile "$TEMP_PROFILE_NAME" >/dev/null 2>&1

echo
echo "已删除临时Profile: $TEMP_PROFILE_NAME"
echo "脚本执行完毕。"

# 如果脚本能执行到这里, 说明创建成功, 不需要回滚了
ROLLBACK_USER_CREATED="false"
