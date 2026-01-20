#!/bin/bash

# ============================================================
# 检查 Nginx 网关状态
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== 检查 Nginx 网关状态 ===${NC}"
echo ""

# 1. 检查容器状态
echo -e "${YELLOW}[1/4] 检查容器状态...${NC}"
docker ps -a | grep geely-gateway

GATEWAY_STATUS=$(docker ps --format '{{.Names}}:{{.Status}}' | grep geely-gateway || echo "not_running")

if echo "$GATEWAY_STATUS" | grep -q "Up"; then
    echo -e "${GREEN}✓ Nginx 容器正在运行${NC}"
elif echo "$GATEWAY_STATUS" | grep -q "Exited"; then
    echo -e "${RED}✗ Nginx 容器已退出${NC}"
    echo "查看退出原因:"
    docker logs geely-gateway --tail 30
    echo ""
    echo "尝试启动:"
    docker start geely-gateway
    sleep 3
else
    echo -e "${RED}✗ Nginx 容器未找到或未运行${NC}"
    echo "尝试启动:"
    docker start geely-gateway 2>/dev/null || echo "容器不存在，需要重新创建"
fi

# 2. 检查端口映射
echo ""
echo -e "${YELLOW}[2/4] 检查端口映射...${NC}"
docker ps | grep geely-gateway | grep -o "0.0.0.0:80->80" || echo "端口映射可能有问题"

# 3. 检查 Nginx 配置
echo ""
echo -e "${YELLOW}[3/4] 检查 Nginx 配置...${NC}"
if docker ps --format '{{.Names}}' | grep -q "geely-gateway"; then
    docker exec geely-gateway nginx -t 2>&1
else
    echo "容器未运行，无法检查配置"
fi

# 4. 检查 Nginx 日志
echo ""
echo -e "${YELLOW}[4/4] 检查 Nginx 日志（最后 20 行）...${NC}"
if docker ps --format '{{.Names}}' | grep -q "geely-gateway"; then
    docker logs geely-gateway --tail 20
else
    echo "容器未运行，无法查看日志"
fi

echo ""
echo -e "${GREEN}=== 检查完成 ===${NC}"
