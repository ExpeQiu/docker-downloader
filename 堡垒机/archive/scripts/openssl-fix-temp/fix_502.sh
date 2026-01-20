#!/bin/bash

# ============================================================
# 502 Bad Gateway 修复脚本
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== 502 Bad Gateway 诊断和修复 ===${NC}"
echo ""

# 1. 检查容器状态
echo -e "${YELLOW}[1/5] 检查容器状态...${NC}"
PORTAL_STATUS=$(docker ps -a --format '{{.Names}}:{{.Status}}' | grep portal-frontend)
echo "$PORTAL_STATUS"

if echo "$PORTAL_STATUS" | grep -q "Exited"; then
    echo -e "${RED}✗ portal-frontend 容器已退出${NC}"
    echo ""
    echo "查看退出原因:"
    docker logs portal-frontend --tail 30
    echo ""
    echo -e "${YELLOW}尝试启动容器...${NC}"
    docker start portal-frontend
    sleep 5
fi

if ! docker ps --format '{{.Names}}' | grep -q "portal-frontend"; then
    echo -e "${RED}✗ portal-frontend 容器未运行${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 容器正在运行${NC}"

# 2. 检查库文件
echo ""
echo -e "${YELLOW}[2/5] 检查库文件...${NC}"
if docker exec portal-frontend test -f /usr/lib/libssl.so.1.1 2>/dev/null; then
    echo "库文件存在:"
    docker exec portal-frontend ls -lh /usr/lib/libssl.so.1.1 /usr/lib/libcrypto.so.1.1 2>/dev/null
    
    # 检查架构
    ARCH=$(docker exec portal-frontend file /usr/lib/libssl.so.1.1 2>/dev/null | grep -o "x86-64\|ARM\|aarch64" || echo "未知")
    echo "架构: $ARCH"
    
    if echo "$ARCH" | grep -q "ARM\|aarch64"; then
        echo -e "${RED}✗ 架构不匹配（需要 x86-64）${NC}"
    fi
    
    # 检查依赖
    echo "检查库文件依赖:"
    docker exec portal-frontend ldd /usr/lib/libssl.so.1.1 2>&1 | head -5
else
    echo -e "${YELLOW}⚠ 库文件不存在${NC}"
fi

# 3. 检查应用日志
echo ""
echo -e "${YELLOW}[3/5] 检查应用日志（最后 30 行）...${NC}"
docker logs portal-frontend --tail 30

# 4. 检查健康检查
echo ""
echo -e "${YELLOW}[4/5] 检查健康检查接口...${NC}"
HEALTH_CODE=$(docker exec geely-gateway curl -s -o /dev/null -w "%{http_code}" http://portal-frontend:3000/api/health 2>/dev/null || echo "000")
echo "健康检查状态码: $HEALTH_CODE"

if [ "$HEALTH_CODE" != "200" ]; then
    echo -e "${RED}✗ 健康检查失败${NC}"
    echo ""
    echo "详细错误:"
    docker exec geely-gateway curl -v http://portal-frontend:3000/api/health 2>&1 | head -20
fi

# 5. 检查 Nginx 日志
echo ""
echo -e "${YELLOW}[5/5] 检查 Nginx 日志（最后 20 行）...${NC}"
docker logs geely-gateway --tail 20 | grep -E "502|error|upstream" || echo "无相关错误"

# 修复建议
echo ""
echo -e "${YELLOW}=== 修复建议 ===${NC}"

if echo "$PORTAL_STATUS" | grep -q "Exited"; then
    echo "1. 容器已退出，尝试重启..."
    docker restart portal-frontend
    sleep 5
    docker ps | grep portal-frontend
fi

if [ "$HEALTH_CODE" != "200" ]; then
    echo ""
    echo "2. 健康检查失败，可能的原因:"
    echo "   - 应用启动失败"
    echo "   - 库文件问题"
    echo "   - 数据库连接问题"
    echo ""
    echo "尝试修复:"
    echo "  a) 查看详细日志: docker logs portal-frontend --tail 50"
    echo "  b) 如果库文件有问题，可以临时移除:"
    echo "     docker exec -u 0 portal-frontend rm /usr/lib/libssl.so.1.1 /usr/lib/libcrypto.so.1.1"
    echo "     docker restart portal-frontend"
    echo "  c) 检查应用配置: docker exec portal-frontend env | grep -E 'DATABASE|REDIS'"
fi

echo ""
echo "诊断完成！"
