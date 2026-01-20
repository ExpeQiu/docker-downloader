#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 安装 OpenSSL 1.1 库文件 ===${NC}"

if [ ! -f "libssl.so.1.1" ] || [ ! -f "libcrypto.so.1.1" ]; then
    echo -e "${RED}✗ 库文件不存在${NC}"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "portal-frontend"; then
    echo -e "${RED}✗ portal-frontend 容器未运行${NC}"
    exit 1
fi

echo "复制库文件到容器..."
# Prisma 引擎需要从 /lib 目录加载，所以同时安装到两个位置
docker cp libssl.so.1.1 portal-frontend:/lib/
docker cp libcrypto.so.1.1 portal-frontend:/lib/
docker cp libssl.so.1.1 portal-frontend:/usr/lib/
docker cp libcrypto.so.1.1 portal-frontend:/usr/lib/

echo "设置权限..."
docker exec -u 0 portal-frontend chmod 755 /lib/libssl.so.1.1 /lib/libcrypto.so.1.1
docker exec -u 0 portal-frontend chmod 755 /usr/lib/libssl.so.1.1 /usr/lib/libcrypto.so.1.1

echo "验证库文件..."
echo "在 /lib 目录:"
docker exec portal-frontend ls -lh /lib/libssl.so.1.1 /lib/libcrypto.so.1.1
echo "在 /usr/lib 目录:"
docker exec portal-frontend ls -lh /usr/lib/libssl.so.1.1 /usr/lib/libcrypto.so.1.1

echo "重启容器..."
docker restart portal-frontend

echo "等待容器启动（10秒）..."
sleep 10

echo ""
echo "验证安装..."
# 检查容器状态
if docker ps --format '{{.Names}}' | grep -q "portal-frontend"; then
    echo -e "${GREEN}✓ 容器正在运行${NC}"
    
    # 检查健康检查
    HEALTH_CODE=$(docker exec geely-gateway curl -s -o /dev/null -w "%{http_code}" http://portal-frontend:3000/api/health 2>/dev/null || echo "000")
    if [ "$HEALTH_CODE" == "200" ]; then
        echo -e "${GREEN}✓ 健康检查: 200 OK${NC}"
    else
        echo -e "${YELLOW}⚠ 健康检查: $HEALTH_CODE${NC}"
        echo "查看日志: docker logs portal-frontend --tail 30"
    fi
else
    echo -e "${RED}✗ 容器启动失败${NC}"
    echo "查看日志: docker logs portal-frontend --tail 50"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ 安装完成!${NC}"
echo "请访问 http://<服务器IP>/api/health 验证"
