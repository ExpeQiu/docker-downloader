#!/bin/bash
# 导出 Writer 项目镜像
echo "正在导出 Writer 镜像 (writer-backend:v1.0, writer-frontend:v1.0)..."
docker save writer-backend:v1.0 writer-frontend:v1.0 -o writer-images.tar
if [ $? -eq 0 ]; then
    echo "✅ 镜像导出成功: writer-images.tar"
else
    echo "❌ 镜像导出失败，请检查本地是否存在 writer-backend:v1.0 和 writer-frontend:v1.0 镜像"
fi
