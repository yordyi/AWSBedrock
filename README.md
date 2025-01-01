# AWS Bedrock IAM用户自动创建脚本

这个脚本可以帮助你快速创建一个具有AWS Bedrock访问权限的IAM用户。

## 功能特点

- 自动创建新的IAM用户
- 自动附加 AmazonBedrockFullAccess 权限
- 自动生成Access Key和Secret Key
- 用户名格式：bedrock-invoke-user-时间戳-随机数
- 支持临时Profile管理

## 使用前提

1. 已安装AWS CLI
2. 已安装jq (用于解析JSON)
3. 拥有可以创建IAM用户的权限（Root账号或有IAM管理权限的用户）

## 使用方法

### 方法一：使用curl直接下载并运行

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/yordyi/AWSBedrock/main/create_iam_user_for_bedrock.sh

# 添加执行权限
chmod +x create_iam_user_for_bedrock.sh

# 运行脚本
./create_iam_user_for_bedrock.sh
```

### 方法二：克隆仓库

1. 克隆仓库：
```bash
git clone https://github.com/yordyi/AWSBedrock.git
cd AWSBedrock
```

2. 添加执行权限：
```bash
chmod +x create_iam_user_for_bedrock.sh
```

3. 运行脚本：
```bash
./create_iam_user_for_bedrock.sh
```

4. 按提示输入有IAM管理权限的Access Key和Secret Key

## 注意事项

- 脚本默认使用us-east-1区域
- Secret Key只会显示一次，请及时保存
- 建议使用有IAM管理权限的子用户，避免使用Root账号
- 请妥善保管所有访问密钥

## 输出示例

```
================== 创建完成 ==================
IAM 用户名:          bedrock-invoke-user-20240101123456-7890
Access Key ID:       AKIAXXXXXXXXXXXXXXXX
Secret Access Key:   XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
附加权限策略:        arn:aws:iam::aws:policy/AmazonBedrockFullAccess
所在Region:          us-east-1
