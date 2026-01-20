#!/bin/bash
# 导入 Writer 项目镜像
if [ -f "writer-images.tar" ]; then
    echo "正在导入 Writer 镜像..."
    docker load -i writer-images.tar
    echo "✅ 镜像导入完成"
else
    echo "❌ 未找到 writer-images.tar 文件"
fi
