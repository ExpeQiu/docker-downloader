#!/bin/bash

# ============================================================
# 修复 Nginx IP 地址不匹配问题
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 修复 Nginx IP 地址问题 ===${NC}"
echo ""

# 1. 检查当前容器 IP
echo -e "${YELLOW}[1/3] 检查容器 IP 地址...${NC}"
ACTUAL_IP=$(docker inspect portal-frontend | grep -A 10 "Networks" | grep "IPAddress" | head -1 | awk '{print $2}' | tr -d '",')
echo "实际容器 IP: $ACTUAL_IP"

# 2. 检查 Nginx 配置
echo ""
echo -e "${YELLOW}[2/3] 检查 Nginx 配置...${NC}"
NGINX_CONFIG=$(docker exec geely-gateway cat /etc/nginx/conf.d/default.conf 2>/dev/null)
if echo "$NGINX_CONFIG" | grep -q "172.20.0.3"; then
    echo -e "${RED}✗ 发现硬编码的旧 IP: 172.20.0.3${NC}"
    echo "Nginx 配置应该使用容器名称 'portal-frontend' 而不是 IP"
elif echo "$NGINX_CONFIG" | grep -q "portal-frontend"; then
    echo -e "${GREEN}✓ Nginx 配置使用容器名称（正确）${NC}"
else
    echo -e "${YELLOW}⚠ 无法确定 Nginx 配置${NC}"
fi

# 3. 重启 Nginx 让它在解析容器名称
echo ""
echo -e "${YELLOW}[3/3] 重启 Nginx 网关...${NC}"
echo "这将让 Nginx 重新解析容器 IP 地址"
docker restart geely-gateway

echo "等待 Nginx 启动（5秒）..."
sleep 5

# 验证
echo ""
echo "验证修复..."
NGINX_STATUS=$(docker ps | grep geely-gateway | awk '{print $7}')
if [ "$NGINX_STATUS" = "Up" ]; then
    echo -e "${GREEN}✓ Nginx 已重启${NC}"
else
    echo -e "${RED}✗ Nginx 启动失败${NC}"
    docker logs geely-gateway --tail 20
    exit 1
fi

# 测试
echo ""
echo "测试访问..."
sleep 2
TEST_RESPONSE=$(docker exec geely-gateway curl -s -o /dev/null -w "%{http_code}" http://portal-frontend:3000/api/health 2>/dev/null || echo "000")
if [ "$TEST_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ 内部访问正常${NC}"
else
    echo -e "${YELLOW}⚠ 内部访问状态码: $TEST_RESPONSE${NC}"
fi

echo ""
echo -e "${GREEN}=== 修复完成 ===${NC}"
echo ""
echo "请测试外部访问:"
echo "  curl http://10.133.23.136/api/health"
echo ""
echo "如果仍然 502，可能需要检查 Nginx 配置文件中是否有硬编码的 IP"
