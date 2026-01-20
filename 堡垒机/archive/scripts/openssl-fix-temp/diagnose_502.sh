#!/bin/bash

# ============================================================
# 502 Bad Gateway 详细诊断脚本
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== 502 Bad Gateway 详细诊断 ===${NC}"
echo ""

# 1. 检查容器状态
echo -e "${YELLOW}[1/6] 检查容器状态...${NC}"
docker ps -a | grep -E "portal|gateway"

# 2. 检查 Nginx 连接
echo ""
echo -e "${YELLOW}[2/6] 检查 Nginx 到后端的连接...${NC}"
echo "测试健康检查接口:"
docker exec geely-gateway curl -v http://portal-frontend:3000/api/health 2>&1 | head -20

echo ""
echo "测试根路径:"
docker exec geely-gateway curl -v http://portal-frontend:3000/ 2>&1 | head -20

# 3. 检查 Nginx 日志
echo ""
echo -e "${YELLOW}[3/6] 检查 Nginx 错误日志（最近 20 行）...${NC}"
docker logs geely-gateway --tail 20 | grep -E "502|error|upstream|connect"

# 4. 检查应用日志
echo ""
echo -e "${YELLOW}[4/6] 检查应用日志（最近 30 行）...${NC}"
docker logs portal-frontend --tail 30

# 5. 检查网络连接
echo ""
echo -e "${YELLOW}[5/6] 检查容器网络...${NC}"
echo "Portal 容器 IP:"
docker inspect portal-frontend | grep -A 10 "Networks" | grep "IPAddress" | head -1

echo ""
echo "从网关测试连接:"
docker exec geely-gateway ping -c 2 portal-frontend 2>&1 | head -5

# 6. 检查端口监听
echo ""
echo -e "${YELLOW}[6/6] 检查应用端口监听...${NC}"
docker exec portal-frontend netstat -tlnp 2>/dev/null | grep 3000 || \
docker exec portal-frontend ss -tlnp 2>/dev/null | grep 3000 || \
echo "无法检查端口（可能需要安装 netstat/ss）"

echo ""
echo "检查进程:"
docker exec portal-frontend ps aux | grep -E "node|next" | head -5

# 7. 测试实际访问
echo ""
echo -e "${YELLOW}[7/7] 测试实际访问...${NC}"
echo "从网关访问根路径:"
RESPONSE=$(docker exec geely-gateway curl -s -o /dev/null -w "%{http_code}" http://portal-frontend:3000/ 2>/dev/null || echo "000")
echo "HTTP 状态码: $RESPONSE"

if [ "$RESPONSE" != "200" ] && [ "$RESPONSE" != "000" ]; then
    echo "详细响应:"
    docker exec geely-gateway curl -v http://portal-frontend:3000/ 2>&1 | head -30
fi

echo ""
echo -e "${GREEN}=== 诊断完成 ===${NC}"
echo ""
echo "根据以上信息，可能的原因："
echo "1. 应用未正常启动（检查进程和端口）"
echo "2. 网络连接问题（检查 ping 和 IP）"
echo "3. Nginx 配置问题（检查 Nginx 日志）"
echo "4. 应用崩溃（检查应用日志）"
