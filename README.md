# AWSBedrock 自动注册脚本

这个仓库包含一个自动化脚本，用于在 AWS 中创建一个具有 Bedrock 访问权限的 IAM 用户。

## 使用方法

在 macOS 上，您可以通过以下步骤一键执行此脚本：

1. 打开终端。

2. 确保您已经安装了 Git。如果没有安装，您可以通过 Homebrew 安装：
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   brew install git
   ```

3. 克隆此仓库：
   ```
   git clone https://github.com/yordyi/AWSBedrock.git
   ```

4. 进入项目目录：
   ```
   cd AWSBedrock
   ```

5. 给脚本添加执行权限：
   ```
   chmod +x create_iam_user_for_bedrock.sh
   ```

6. 执行脚本：
   ```
   ./create_iam_user_for_bedrock.sh
   ```

7. 按照提示输入您的 AWS Access Key ID 和 Secret Access Key。

脚本将自动创建一个新的 IAM 用户，并为其分配 Bedrock 访问权限。完成后，脚本会显示新用户的 Access Key ID 和 Secret Access Key。请务必保存这些信息，因为 Secret Access Key 只会显示一次。

## 注意事项

- 请确保您输入的 AWS 凭证具有创建 IAM 用户和分配策略的权限。
- 脚本默认使用 `us-east-1` 区域。如果需要更改，请编辑脚本中的 `AWS_REGION` 变量。
- 执行脚本需要安装 `jq`。如果没有安装，可以通过以下命令安装：
  ```
  brew install jq
  ```

## 安全提示

- 请不要将您的 AWS 凭证提交到 Git 仓库或分享给他人。
- 建议在使用完毕后，删除或禁用创建的 IAM 用户的访问密钥。

如果您在使用过程中遇到任何问题，请创建一个 issue 来反馈。
