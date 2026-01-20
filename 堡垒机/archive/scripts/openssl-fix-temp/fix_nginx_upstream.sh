#!/bin/bash

# ============================================================
# 修复 Nginx upstream 配置问题
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 修复 Nginx upstream 配置 ===${NC}"
echo ""

# 1. 检查 writer-backend 容器
echo -e "${YELLOW}[1/4] 检查 writer-backend 容器...${NC}"
if docker ps --format '{{.Names}}' | grep -q "writer-backend"; then
    echo -e "${GREEN}✓ writer-backend 容器正在运行${NC}"
    docker ps | grep writer-backend
elif docker ps -a --format '{{.Names}}' | grep -q "writer-backend"; then
    echo -e "${YELLOW}⚠ writer-backend 容器存在但未运行${NC}"
    echo "尝试启动..."
    docker start writer-backend
    sleep 3
    if docker ps --format '{{.Names}}' | grep -q "writer-backend"; then
        echo -e "${GREEN}✓ writer-backend 已启动${NC}"
    else
        echo -e "${RED}✗ writer-backend 启动失败${NC}"
        echo "需要修复 Nginx 配置或启动 writer-backend 容器"
    fi
else
    echo -e "${RED}✗ writer-backend 容器不存在${NC}"
    echo "需要修复 Nginx 配置"
fi

# 2. 检查其他后端容器
echo ""
echo -e "${YELLOW}[2/4] 检查其他后端容器...${NC}"
BACKENDS=("tpd2-backend" "todify4-backend" "writer-backend")
MISSING_BACKENDS=()

for BACKEND in "${BACKENDS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "$BACKEND"; then
        echo -e "${GREEN}✓ $BACKEND 正在运行${NC}"
    else
        echo -e "${YELLOW}⚠ $BACKEND 未运行${NC}"
        MISSING_BACKENDS+=("$BACKEND")
    fi
done

# 3. 修复 Nginx 配置（临时方案）
if [ ${#MISSING_BACKENDS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}[3/4] 修复 Nginx 配置...${NC}"
    echo "缺失的容器: ${MISSING_BACKENDS[*]}"
    echo ""
    echo "方案 1: 启动缺失的容器（推荐）"
    echo "  执行: docker-compose up -d"
    echo ""
    echo "方案 2: 临时修复 Nginx 配置"
    echo "  需要修改 nginx/default.conf，注释掉缺失的 upstream"
    echo ""
    echo "当前 Nginx 配置位置:"
    docker inspect geely-gateway | grep -A 5 "Mounts" | grep "Source" | head -1
else
    echo ""
    echo -e "${GREEN}✓ 所有后端容器都在运行${NC}"
fi

# 4. 重启 Nginx
echo ""
echo -e "${YELLOW}[4/4] 重启 Nginx...${NC}"

# 先停止容器
docker stop geely-gateway 2>/dev/null
sleep 2

# 如果所有后端都在运行，启动 Nginx
if [ ${#MISSING_BACKENDS[@]} -eq 0 ]; then
    docker start geely-gateway
    sleep 5
    
    if docker ps --format '{{.Names}}' | grep -q "geely-gateway"; then
        echo -e "${GREEN}✓ Nginx 已启动${NC}"
        docker ps | grep geely-gateway
    else
        echo -e "${RED}✗ Nginx 启动失败${NC}"
        docker logs geely-gateway --tail 20
    fi
else
    echo -e "${RED}✗ 无法启动 Nginx（缺少后端容器）${NC}"
    echo ""
    echo "请先执行以下操作之一:"
    echo "  1. 启动缺失的容器: docker-compose up -d"
    echo "  2. 修改 Nginx 配置，注释掉缺失的 upstream"
fi

echo ""
echo -e "${GREEN}=== 完成 ===${NC}"
