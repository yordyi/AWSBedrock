#!/bin/bash

# 下载脚本
curl -O https://raw.githubusercontent.com/yordyi/AWSBedrock/master/create_iam_user_for_bedrock.sh

# 给脚本添加执行权限
chmod +x create_iam_user_for_bedrock.sh

# 执行脚本
./create_iam_user_for_bedrock.sh

# 清理：删除下载的脚本（可选，取决于您是否希望保留脚本）
# rm create_iam_user_for_bedrock.sh
