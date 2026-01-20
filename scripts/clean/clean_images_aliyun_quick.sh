#!/bin/bash

# 阿里云服务器 Docker 镜像快速清理脚本（非交互式）
# 服务器: root@47.113.225.93
# 默认清理: dangling 镜像 + 未使用的镜像

SERVER="root@47.113.225.93"
PASSWORD="Qb89100820"

echo "=========================================="
echo "阿里云服务器 Docker 镜像快速清理"
echo "服务器: 47.113.225.93"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 检查 Docker 是否安装
DOCKER_CHECK=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker --version 2>&1")
if [[ $? -ne 0 ]]; then
    echo "错误: Docker 未安装或无法访问"
    exit 1
fi

# 显示清理前的状态
echo "【清理前状态】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker system df"
echo ""

# 清理 dangling 镜像
echo "【清理 dangling 镜像】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker image prune -f"
echo ""

# 清理未使用的镜像（保留正在使用的）
echo "【清理未使用的镜像】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker image prune -a -f"
echo ""

# 显示清理后的状态
echo "【清理后状态】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker system df"
echo ""

# 显示磁盘使用情况
echo "【磁盘使用情况】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "df -h /"
echo ""

echo "=========================================="
echo "清理完成"
echo "=========================================="
