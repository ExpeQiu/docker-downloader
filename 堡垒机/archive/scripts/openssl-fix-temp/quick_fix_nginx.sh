#!/bin/bash

# ============================================================
# 快速修复 Nginx writer-backend 问题
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 快速修复 Nginx 配置 ===${NC}"
echo ""

# 1. 检查 writer-backend
echo -e "${YELLOW}[1/3] 检查 writer-backend 容器...${NC}"
if docker ps --format '{{.Names}}' | grep -q "writer-backend"; then
    echo -e "${GREEN}✓ writer-backend 正在运行${NC}"
    echo "无需修改配置，只需重启 Nginx"
    docker restart geely-gateway
    sleep 5
    docker ps | grep geely-gateway
    exit 0
elif docker ps -a --format '{{.Names}}' | grep -q "writer-backend"; then
    echo "尝试启动 writer-backend..."
    docker start writer-backend
    sleep 5
    if docker ps --format '{{.Names}}' | grep -q "writer-backend"; then
        echo -e "${GREEN}✓ writer-backend 已启动${NC}"
        docker restart geely-gateway
        sleep 5
        exit 0
    fi
fi

echo -e "${RED}✗ writer-backend 不存在或无法启动${NC}"
echo "需要修改 Nginx 配置"

# 2. 找到配置文件
echo ""
echo -e "${YELLOW}[2/3] 查找 Nginx 配置文件...${NC}"
CONFIG_FILE=$(docker inspect geely-gateway 2>/dev/null | grep -A 20 "Mounts" | grep -A 5 "Source" | grep "Source" | head -1 | awk -F'"' '{print $4}' || echo "")

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    # 尝试从 docker-compose.yml 推断路径
    if [ -f "../nginx/default.conf" ]; then
        CONFIG_FILE="../nginx/default.conf"
    elif [ -f "./nginx/default.conf" ]; then
        CONFIG_FILE="./nginx/default.conf"
    elif [ -f "/root/unified-deploy/nginx/default.conf" ]; then
        CONFIG_FILE="/root/unified-deploy/nginx/default.conf"
    else
        echo -e "${RED}✗ 无法找到配置文件${NC}"
        echo ""
        echo "请手动执行以下操作:"
        echo "  1. 找到 nginx/default.conf 文件"
        echo "  2. 注释掉第 78 行: proxy_pass http://writer-backend:8000/;"
        echo "  3. 重启 Nginx: docker restart geely-gateway"
        exit 1
    fi
fi

echo "配置文件: $CONFIG_FILE"

# 3. 备份并修改配置
echo ""
echo -e "${YELLOW}[3/3] 修改配置文件...${NC}"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✓ 已备份到: $BACKUP_FILE"

# 注释掉 writer-backend 的 proxy_pass
sed -i 's|proxy_pass http://writer-backend:8000/;|# proxy_pass http://writer-backend:8000/; # 临时注释：容器不存在|g' "$CONFIG_FILE"

# 或者直接注释掉整个 location 块（更安全）
sed -i '/location \/writer-api\//,/^    }/s/^/# /' "$CONFIG_FILE" 2>/dev/null || \
sed -i '77,80s/^/# /' "$CONFIG_FILE"

echo -e "${GREEN}✓ 配置已修改${NC}"

# 4. 重启 Nginx
echo ""
echo "重启 Nginx..."
docker restart geely-gateway
sleep 5

# 验证
if docker ps --format '{{.Names}}' | grep -q "geely-gateway"; then
    STATUS=$(docker ps --format '{{.Status}}' | grep geely-gateway)
    if echo "$STATUS" | grep -q "Up" && ! echo "$STATUS" | grep -q "Restarting"; then
        echo -e "${GREEN}✓ Nginx 已成功启动${NC}"
        docker ps | grep geely-gateway
    else
        echo -e "${YELLOW}⚠ Nginx 状态: $STATUS${NC}"
        docker logs geely-gateway --tail 10
    fi
else
    echo -e "${RED}✗ Nginx 启动失败${NC}"
    docker logs geely-gateway --tail 20
    exit 1
fi

echo ""
echo -e "${GREEN}=== 修复完成 ===${NC}"
echo ""
echo "测试访问:"
echo "  curl http://10.133.23.136/api/health"
