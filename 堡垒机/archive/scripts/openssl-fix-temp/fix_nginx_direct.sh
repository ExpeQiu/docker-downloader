#!/bin/bash

# ============================================================
# 直接修复 Nginx 配置 - 找到配置文件并修改
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 直接修复 Nginx 配置 ===${NC}"
echo ""

# 1. 停止 Nginx（避免重启循环）
echo -e "${YELLOW}[1/4] 停止 Nginx 容器...${NC}"
docker stop geely-gateway 2>/dev/null
sleep 2

# 2. 查找配置文件
echo -e "${YELLOW}[2/4] 查找配置文件...${NC}"

# 方法 1: 从容器挂载信息获取
CONFIG_FILE=$(docker inspect geely-gateway 2>/dev/null | grep -A 20 "Mounts" | grep -B 5 "default.conf" | grep "Source" | head -1 | awk -F'"' '{print $4}' || echo "")

# 方法 2: 尝试常见路径
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    COMMON_PATHS=(
        "/root/unified-deploy/nginx/default.conf"
        "./nginx/default.conf"
        "../nginx/default.conf"
        "$(pwd)/../nginx/default.conf"
        "/root/nginx/default.conf"
    )
    
    for path in "${COMMON_PATHS[@]}"; do
        if [ -f "$path" ]; then
            CONFIG_FILE="$path"
            break
        fi
    done
fi

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}✗ 无法找到配置文件${NC}"
    echo ""
    echo "请手动查找配置文件:"
    echo "  1. docker inspect geely-gateway | grep -A 10 Mounts"
    echo "  2. 找到 Source 路径"
    echo "  3. 编辑该文件，注释掉 writer-backend 的 proxy_pass"
    exit 1
fi

echo -e "${GREEN}✓ 找到配置文件: $CONFIG_FILE${NC}"

# 3. 备份并修改
echo -e "${YELLOW}[3/4] 备份并修改配置...${NC}"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✓ 已备份到: $BACKUP_FILE"

# 修改配置 - 注释掉 writer-backend 的 proxy_pass
sed -i 's|proxy_pass http://writer-backend:8000/;|# proxy_pass http://writer-backend:8000/; # 临时注释：容器不存在|g' "$CONFIG_FILE"

# 验证修改
if grep -q "^# proxy_pass http://writer-backend:8000/" "$CONFIG_FILE" || grep -q "# proxy_pass http://writer-backend:8000/" "$CONFIG_FILE"; then
    echo -e "${GREEN}✓ 配置已修改${NC}"
    echo "修改后的配置（第 77-80 行）:"
    sed -n '77,80p' "$CONFIG_FILE"
else
    echo -e "${YELLOW}⚠ 配置修改可能失败，检查文件内容:${NC}"
    grep -n "writer-backend" "$CONFIG_FILE" | head -5
fi

# 4. 启动 Nginx
echo ""
echo -e "${YELLOW}[4/4] 启动 Nginx...${NC}"
docker start geely-gateway
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
        echo -e "${RED}✗ Nginx 仍在重启中，状态: $STATUS${NC}"
        echo "查看最新日志:"
        docker logs geely-gateway --tail 10
    fi
else
    echo -e "${RED}✗ Nginx 启动失败${NC}"
    docker logs geely-gateway --tail 20
    exit 1
fi

echo ""
echo -e "${GREEN}=== 修复完成 ===${NC}"
