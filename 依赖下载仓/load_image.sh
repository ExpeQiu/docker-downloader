#!/bin/bash

# 查找并加载下载的 Docker 镜像
# 使用方法：将 GitHub Action 下载的 artifact 解压后放到当前目录，运行此脚本

echo "正在查找镜像文件..."

# 处理 zip 文件 (GitHub Artifact 默认下载为 zip)
for zip_file in downloaded-images*.zip; do
    if [ -f "$zip_file" ]; then
        echo "发现压缩包: $zip_file，正在解压..."
        unzip -o "$zip_file"
    fi
done

# 处理 tar.gz 文件
FOUND=0
for img_file in docker-images-*.tar.gz; do
    if [ -f "$img_file" ]; then
        FOUND=1
        echo "正在加载镜像文件: $img_file ..."
        # 使用 gunzip 解压并传输给 docker load
        if gunzip -c "$img_file" | docker load; then
            echo "✅ 成功加载: $img_file"
            # 可选：加载成功后删除文件以节省空间
            # rm "$img_file"
        else
            echo "❌ 加载失败: $img_file"
        fi
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "未找到 'docker-images-*.tar.gz' 文件。"
    echo "请先从 GitHub Actions 下载 artifact，解压后将文件放入此目录。"
fi
