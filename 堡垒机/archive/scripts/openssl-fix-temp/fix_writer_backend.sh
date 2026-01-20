#!/bin/bash

# ============================================================
# 修复 writer-backend 问题
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 修复 writer-backend 问题 ===${NC}"
echo ""

# 方案 1: 尝试启动 writer-backend
echo -e "${YELLOW}[方案 1] 尝试启动 writer-backend 容器...${NC}"

if docker ps -a --format '{{.Names}}' | grep -q "writer-backend"; then
    echo "容器存在，尝试启动..."
    docker start writer-backend
    sleep 5
    
    if docker ps --format '{{.Names}}' | grep -q "writer-backend"; then
        echo -e "${GREEN}✓ writer-backend 已启动${NC}"
        echo "重启 Nginx..."
        docker restart geely-gateway
        sleep 5
        
        if docker ps --format '{{.Names}}' | grep -q "geely-gateway" && ! docker ps --format '{{.Status}}' | grep geely-gateway | grep -q "Restarting"; then
            echo -e "${GREEN}✓ Nginx 已启动${NC}"
            docker ps | grep geely-gateway
            echo ""
            echo "测试访问:"
            curl -s http://10.133.23.136/api/health | head -1 || echo "测试中..."
            exit 0
        fi
    else
        echo -e "${RED}✗ writer-backend 启动失败${NC}"
        docker logs writer-backend --tail 10 2>/dev/null || echo "无法查看日志"
    fi
else
    echo -e "${YELLOW}⚠ writer-backend 容器不存在${NC}"
fi

# 方案 2: 修改 Nginx 配置
echo ""
echo -e "${YELLOW}[方案 2] 修改 Nginx 配置（注释掉 writer-backend）...${NC}"

# 查找配置文件
CONFIG_PATHS=(
    "/root/unified-deploy/nginx/default.conf"
    "./nginx/default.conf"
    "../nginx/default.conf"
    "$(pwd)/nginx/default.conf"
)

CONFIG_FILE=""
for path in "${CONFIG_PATHS[@]}"; do
    if [ -f "$path" ]; then
        CONFIG_FILE="$path"
        break
    fi
done

# 如果找不到，从容器挂载信息获取
if [ -z "$CONFIG_FILE" ]; then
    MOUNT_INFO=$(docker inspect geely-gateway 2>/dev/null | grep -A 20 "Mounts" | grep -A 5 "Source" | grep "Source" | head -1)
    if [ -n "$MOUNT_INFO" ]; then
        CONFIG_FILE=$(echo "$MOUNT_INFO" | awk -F'"' '{print $4}')
    fi
fi

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}✗ 无法找到配置文件${NC}"
    echo ""
    echo "请手动执行以下操作:"
    echo "  1. 找到 nginx/default.conf 文件"
    echo "  2. 编辑文件，找到第 77-80 行（writer-api 配置）"
    echo "  3. 注释掉 proxy_pass 行:"
    echo "     # proxy_pass http://writer-backend:8000/;"
    echo "  4. 重启 Nginx: docker restart geely-gateway"
    exit 1
fi

echo "找到配置文件: $CONFIG_FILE"

# 备份
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✓ 已备份到: $BACKUP_FILE"

# 修改配置 - 注释掉 writer-backend 的 proxy_pass
sed -i 's|proxy_pass http://writer-backend:8000/;|# proxy_pass http://writer-backend:8000/; # 临时注释：容器不存在|g' "$CONFIG_FILE"

# 验证修改
if grep -q "^# proxy_pass http://writer-backend:8000/" "$CONFIG_FILE"; then
    echo -e "${GREEN}✓ 配置已修改${NC}"
else
    echo -e "${YELLOW}⚠ 配置修改可能失败，请手动检查${NC}"
fi

# 重启 Nginx
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
        echo ""
        echo "测试访问:"
        sleep 2
        curl -s http://10.133.23.136/api/health | head -1 || echo "测试中..."
    else
        echo -e "${RED}✗ Nginx 仍在重启中${NC}"
        docker logs geely-gateway --tail 10
    fi
else
    echo -e "${RED}✗ Nginx 启动失败${NC}"
    docker logs geely-gateway --tail 20
    exit 1
fi

echo ""
echo -e "${GREEN}=== 修复完成 ===${NC}"
