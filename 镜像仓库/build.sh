#!/bin/bash

# ================= 配置区域 =================
# 阿里云镜像仓库地址
REGISTRY="crpi-c6gwhxgtx8ccdxfl.cn-guangzhou.personal.cr.aliyuncs.com"
# 镜像命名空间和名称
NAMESPACE="cyberspaceai"
IMAGE_NAME="aiforworld"
# 阿里云账号信息 (建议通过环境变量传入，这里为了演示方便直接写入，注意保密)
ALIYUN_USER="dt_4157768178"
# 密码建议手动输入或通过环境变量，不要写在脚本里
# export ALIYUN_PWD="你的密码" 

# 获取当前时间作为版本号 (例如: 20231027-1030)
TAG=$(date +%Y%m%d-%H%M)
FULL_IMAGE_NAME="$REGISTRY/$NAMESPACE/$IMAGE_NAME"

# ================= 镜像加速配置 (2026-01-16 更新) =================
# 解决国内 Docker Hub 拉取失败 (pull access denied) 问题
# 配合 Dockerfile 中的 ARG 使用 (例如: ARG BASE_IMAGE=node:20-alpine)
# 常用 DaoCloud 加速地址示例:
# node:20-alpine -> m.daocloud.io/docker.io/library/node:20-alpine
# nginx:alpine   -> m.daocloud.io/docker.io/library/nginx:alpine
BASE_IMAGE_MIRROR="m.daocloud.io/docker.io/library/node:20-alpine"

echo "========================================================"
echo "🚀 开始构建流程..."
echo "📦 镜像地址: $FULL_IMAGE_NAME"
echo "🏷️  本次版本: $TAG"
echo "========================================================"

# 1. 登录阿里云 (如果已经登录过，可以注释掉)
# 检查是否传入了密码环境变量，如果有则自动登录
if [ -n "$ALIYUN_PWD" ]; then
    echo "🔑 检测到环境变量，正在自动登录阿里云..."
    echo "$ALIYUN_PWD" | docker login --username=$ALIYUN_USER --password-stdin $REGISTRY
else
    echo "⚠️  未检测到 ALIYUN_PWD 环境变量，尝试直接使用现有登录状态..."
    # 也可以取消下面的注释强制手动输入密码登录
    # docker login --username=$ALIYUN_USER $REGISTRY
fi

# 2. 构建镜像
echo "🔨 正在构建镜像 (架构: linux/amd64)..."
# 注意：为了兼容云服务器，这里强制指定构建为 linux/amd64 架构
# 如果你的服务器是 ARM (如 树莓派)，请改为 linux/arm64
docker buildx build --platform linux/amd64 -t "$FULL_IMAGE_NAME:$TAG" -t "$FULL_IMAGE_NAME:latest" .

if [ $? -ne 0 ]; then
    echo "❌ 构建失败！"
    exit 1
fi

# 3. 推送镜像
echo " 正在推送镜像到阿里云..."
docker push "$FULL_IMAGE_NAME:$TAG"
docker push "$FULL_IMAGE_NAME:latest"

if [ $? -eq 0 ]; then
    echo "========================================================"
    echo "✅ 成功！镜像已发布。"
    echo "🌍 公网拉取命令: docker pull $FULL_IMAGE_NAME:$TAG"
    echo "🏠 VPC拉取命令:  docker pull ${FULL_IMAGE_NAME//.aliyuncs.com/-vpc.aliyuncs.com}:$TAG"
    echo "========================================================"
else
    echo "❌ 推送失败，请检查网络或登录状态。"
    exit 1
fi
