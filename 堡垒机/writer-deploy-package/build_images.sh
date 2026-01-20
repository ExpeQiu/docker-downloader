#!/bin/bash
set -e

echo "🚀 开始构建 Writer 项目镜像..."

# 1. 构建后端镜像
echo "📦 构建 writer-backend:v1.0 ..."
cd /Volumes/Lexar/git/03T/writer/backend
docker build -t writer-backend:v1.0 .
if [ $? -eq 0 ]; then
    echo "✅ 后端镜像构建成功"
else
    echo "❌ 后端镜像构建失败"
    exit 1
fi

# 2. 构建前端镜像
echo "📦 构建 writer-frontend:v1.0 ..."
cd /Volumes/Lexar/git/03T/writer/frontend
# 注入构建时环境变量，指向生产环境网关地址
docker build \
  --build-arg NEXT_PUBLIC_API_URL=http://10.133.23.136:8228 \
  -t writer-frontend:v1.0 .
if [ $? -eq 0 ]; then
    echo "✅ 前端镜像构建成功"
else
    echo "❌ 前端镜像构建失败"
    exit 1
fi

echo "🎉 所有镜像构建完成！"
echo "👉 现在可以运行 ./save_images.sh 导出镜像包了"
