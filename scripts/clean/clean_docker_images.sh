#!/bin/bash

# 清理阿里云服务器无用 Docker 镜像脚本
# 服务器: root@47.113.225.93

SERVER="root@47.113.225.93"
PASSWORD="Qb89100820"

echo "=========================================="
echo "Docker 镜像清理工具"
echo "服务器: 47.113.225.93"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 显示当前镜像使用情况
echo "【当前镜像使用情况】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker images"
echo ""

# 显示磁盘使用情况
echo "【Docker 磁盘使用情况】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker system df"
echo ""

# 显示 dangling 镜像（无标签的镜像）
echo "【Dangling 镜像（无标签）】"
DANGLING=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker images -f 'dangling=true' -q")
if [ -z "$DANGLING" ]; then
    echo "无 dangling 镜像"
else
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker images -f 'dangling=true'"
fi
echo ""

# 显示未使用的镜像（未被容器引用的镜像）
echo "【未使用的镜像】"
UNUSED=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker images --format '{{.ID}}' | xargs -I {} docker ps -a --filter ancestor={} --format '{{.ID}}' | wc -l")
echo ""

# 交互式清理选项
echo "请选择清理选项："
echo "1. 清理 dangling 镜像（安全，仅清理无标签镜像）"
echo "2. 清理所有未使用的镜像（包括未使用的标签镜像）"
echo "3. 清理所有未使用的资源（镜像、容器、网络、构建缓存）"
echo "4. 仅查看，不清理"
echo ""
read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        echo "正在清理 dangling 镜像..."
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker image prune -f"
        echo "清理完成"
        ;;
    2)
        echo "正在清理所有未使用的镜像..."
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker image prune -a -f"
        echo "清理完成"
        ;;
    3)
        echo "正在清理所有未使用的资源..."
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker system prune -a -f"
        echo "清理完成"
        ;;
    4)
        echo "仅查看模式，未执行清理操作"
        ;;
    *)
        echo "无效选项，退出"
        exit 1
        ;;
esac

echo ""
echo "【清理后磁盘使用情况】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker system df"
echo ""

echo "=========================================="
echo "操作完成"
echo "=========================================="
