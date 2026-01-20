#!/bin/bash

# ============================================================
# 修复 Nginx 配置 - 处理缺失的后端容器
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 修复 Nginx 配置问题 ===${NC}"
echo ""

# 检查容器状态
echo -e "${YELLOW}[1/3] 检查后端容器状态...${NC}"
docker ps --format '{{.Names}}' | grep -E "backend|frontend" | sort

# 检查 writer-backend
if docker ps --format '{{.Names}}' | grep -q "writer-backend"; then
    echo -e "${GREEN}✓ writer-backend 正在运行${NC}"
    FIX_NEEDED=false
elif docker ps -a --format '{{.Names}}' | grep -q "writer-backend"; then
    echo -e "${YELLOW}⚠ writer-backend 存在但未运行，尝试启动...${NC}"
    docker start writer-backend
    sleep 3
    if docker ps --format '{{.Names}}' | grep -q "writer-backend"; then
        echo -e "${GREEN}✓ writer-backend 已启动${NC}"
        FIX_NEEDED=false
    else
        echo -e "${RED}✗ writer-backend 启动失败${NC}"
        FIX_NEEDED=true
    fi
else
    echo -e "${RED}✗ writer-backend 容器不存在${NC}"
    FIX_NEEDED=true
fi

# 修复方案
if [ "$FIX_NEEDED" = true ]; then
    echo ""
    echo -e "${YELLOW}[2/3] 应用修复方案...${NC}"
    
    # 获取 Nginx 配置文件的挂载路径
    CONFIG_PATH=$(docker inspect geely-gateway 2>/dev/null | grep -A 10 "Mounts" | grep "Source" | head -1 | awk '{print $2}' | tr -d '",')
    
    if [ -z "$CONFIG_PATH" ]; then
        echo "无法找到配置文件路径"
        echo "请手动修改 Nginx 配置，注释掉 writer-backend 相关配置"
        exit 1
    fi
    
    echo "配置文件路径: $CONFIG_PATH"
    
    # 备份配置
    if [ -f "$CONFIG_PATH" ]; then
        cp "$CONFIG_PATH" "${CONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✓ 配置已备份"
        
        # 临时修复：注释掉 writer-backend 的配置
        echo "临时修复：注释掉 writer-backend 配置..."
        sed -i 's|proxy_pass http://writer-backend:8000/;|# proxy_pass http://writer-backend:8000/; # 临时注释：容器不存在|g' "$CONFIG_PATH"
        
        echo -e "${GREEN}✓ 配置已修改${NC}"
    else
        echo -e "${RED}✗ 配置文件不存在: $CONFIG_PATH${NC}"
        echo ""
        echo "请手动修改配置文件，注释掉以下行:"
        echo "  location /writer-api/ {"
        echo "      proxy_pass http://writer-backend:8000/;"
        echo "  }"
        exit 1
    fi
else
    echo ""
    echo -e "${GREEN}[2/3] 无需修复，所有容器都在运行${NC}"
fi

# 重启 Nginx
echo ""
echo -e "${YELLOW}[3/3] 重启 Nginx...${NC}"
docker restart geely-gateway
sleep 5

# 验证
if docker ps --format '{{.Names}}' | grep -q "geely-gateway"; then
    echo -e "${GREEN}✓ Nginx 已启动${NC}"
    docker ps | grep geely-gateway
    
    echo ""
    echo "测试访问:"
    sleep 2
    curl -s http://10.133.23.136/api/health | head -1 || echo "连接测试..."
else
    echo -e "${RED}✗ Nginx 启动失败${NC}"
    docker logs geely-gateway --tail 20
fi

echo ""
echo -e "${GREEN}=== 完成 ===${NC}"
