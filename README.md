# AWSBedrock 自动注册脚本

这个仓库包含一个自动化脚本，用于在 AWS 中创建一个具有 Bedrock 访问权限的 IAM 用户。

## 使用方法

### 方法一：使用 curl 一键安装和执行（推荐）

在 macOS 上，您可以通过以下命令一键下载并执行脚本：

```bash
curl -sSL https://raw.githubusercontent.com/yordyi/AWSBedrock/main/install.sh | bash
```

这个命令会自动下载安装脚本，并执行它。脚本会进一步下载并运行 `create_iam_user_for_bedrock.sh`。

### 方法二：手动克隆仓库并执行

如果您更喜欢手动操作，可以按照以下步骤执行：

1. 打开终端。

2. 克隆此仓库：
   ```
   git clone https://github.com/yordyi/AWSBedrock.git
   ```

3. 进入项目目录：
   ```
   cd AWSBedrock
   ```

4. 给脚本添加执行权限：
   ```
   chmod +x create_iam_user_for_bedrock.sh
   ```

5. 执行脚本：
   ```
   ./create_iam_user_for_bedrock.sh
   ```

无论您选择哪种方法，都需要按照提示输入您的 AWS Access Key ID 和 Secret Access Key。

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
