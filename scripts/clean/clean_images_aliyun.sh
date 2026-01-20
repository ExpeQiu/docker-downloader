#!/bin/bash

# 阿里云服务器 Docker 镜像清理脚本
# 服务器: root@47.113.225.93

SERVER="root@47.113.225.93"
PASSWORD="Qb89100820"

echo "=========================================="
echo "阿里云服务器 Docker 镜像清理"
echo "服务器: 47.113.225.93"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 检查 Docker 是否安装
echo "【检查 Docker 状态】"
DOCKER_CHECK=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker --version 2>&1")
if [[ $? -ne 0 ]]; then
    echo "错误: Docker 未安装或无法访问"
    exit 1
fi
echo "$DOCKER_CHECK"
echo ""

# 显示清理前的磁盘使用情况
echo "【清理前磁盘使用情况】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "df -h /"
echo ""

# 显示当前镜像列表
echo "【当前 Docker 镜像列表】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker images"
echo ""

# 显示镜像占用空间统计
echo "【镜像占用空间统计】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker system df"
echo ""

# 询问清理级别
echo "请选择清理级别:"
echo "1) 仅清理 dangling 镜像（无标签的镜像，安全）"
echo "2) 清理所有未使用的镜像（包括未使用的镜像，较安全）"
echo "3) 清理所有未使用的资源（镜像、容器、网络、构建缓存，谨慎）"
echo "4) 仅查看，不清理"
read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        echo ""
        echo "【清理 dangling 镜像】"
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker image prune -f"
        ;;
    2)
        echo ""
        echo "【清理所有未使用的镜像】"
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker image prune -a -f"
        ;;
    3)
        echo ""
        echo "⚠️  警告: 将清理所有未使用的资源（镜像、容器、网络、构建缓存）"
        read -p "确认继续？(y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker system prune -a -f --volumes"
        else
            echo "已取消清理"
            exit 0
        fi
        ;;
    4)
        echo ""
        echo "仅查看模式，未执行清理"
        exit 0
        ;;
    *)
        echo "无效选项，退出"
        exit 1
        ;;
esac

echo ""
echo "【清理后磁盘使用情况】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "df -h /"
echo ""

echo "【清理后镜像占用空间统计】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker system df"
echo ""

echo "=========================================="
echo "清理完成"
echo "=========================================="
