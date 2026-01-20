#!/bin/bash

# ============================================================
# 修复 libssl.so.1.1 路径问题
# Prisma 引擎需要从 /lib 目录加载库文件
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 修复 libssl.so.1.1 路径问题 ===${NC}"
echo ""

# 检查容器状态
if ! docker ps --format '{{.Names}}' | grep -q "portal-frontend"; then
    echo -e "${RED}✗ portal-frontend 容器未运行${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/4] 检查当前库文件位置...${NC}"
docker exec portal-frontend ls -lh /usr/lib/libssl.so.1.1 /usr/lib/libcrypto.so.1.1 2>/dev/null || echo "库文件不在 /usr/lib"

echo -e "${YELLOW}[2/4] 检查 /lib 目录...${NC}"
docker exec portal-frontend ls -lh /lib/libssl.so.1.1 /lib/libcrypto.so.1.1 2>/dev/null || echo "库文件不在 /lib"

echo -e "${YELLOW}[3/4] 复制库文件到 /lib 目录（Prisma 需要的位置）...${NC}"

# 如果库文件在 /usr/lib，复制到 /lib
if docker exec portal-frontend test -f /usr/lib/libssl.so.1.1 2>/dev/null; then
    echo "从 /usr/lib 复制到 /lib..."
    docker exec -u 0 portal-frontend cp /usr/lib/libssl.so.1.1 /lib/libssl.so.1.1
    docker exec -u 0 portal-frontend cp /usr/lib/libcrypto.so.1.1 /lib/libcrypto.so.1.1
    docker exec -u 0 portal-frontend chmod 755 /lib/libssl.so.1.1 /lib/libcrypto.so.1.1
    echo -e "${GREEN}✓ 库文件已复制到 /lib${NC}"
elif docker exec portal-frontend test -f /lib/libssl.so.1.1 2>/dev/null; then
    echo -e "${GREEN}✓ 库文件已在 /lib 目录${NC}"
else
    echo -e "${RED}✗ 未找到库文件，需要先安装${NC}"
    echo "请先运行: ./install_libs.sh"
    exit 1
fi

# 如果本地有库文件，也可以直接复制
if [ -f "libssl.so.1.1" ] && [ -f "libcrypto.so.1.1" ]; then
    echo "从本地文件复制到容器 /lib..."
    docker cp libssl.so.1.1 portal-frontend:/lib/
    docker cp libcrypto.so.1.1 portal-frontend:/lib/
    docker exec -u 0 portal-frontend chmod 755 /lib/libssl.so.1.1 /lib/libcrypto.so.1.1
    echo -e "${GREEN}✓ 库文件已复制到 /lib${NC}"
fi

echo -e "${YELLOW}[4/4] 验证库文件...${NC}"
docker exec portal-frontend ls -lh /lib/libssl.so.1.1 /lib/libcrypto.so.1.1

# 检查库文件依赖
echo ""
echo "检查库文件依赖:"
docker exec portal-frontend ldd /lib/libssl.so.1.1 2>&1 | head -5

# 验证 Prisma 引擎能否找到库文件
echo ""
echo "测试 Prisma 引擎库文件加载:"
docker exec portal-frontend sh -c "LD_LIBRARY_PATH=/lib:/usr/lib ldd /app/node_modules/.prisma/client/libquery_engine-linux-musl.so.node 2>&1 | grep libssl" || echo "无法直接测试"

echo ""
echo -e "${YELLOW}重启容器...${NC}"
docker restart portal-frontend

echo "等待容器启动（10秒）..."
sleep 10

echo ""
echo "检查容器状态:"
docker ps | grep portal-frontend

echo ""
echo "检查应用日志（最后 10 行）:"
docker logs portal-frontend --tail 10

echo ""
echo -e "${GREEN}=== 修复完成 ===${NC}"
echo ""
echo "请检查:"
echo "  1. 容器是否正常运行: docker ps | grep portal-frontend"
echo "  2. 健康检查: docker exec geely-gateway curl http://portal-frontend:3000/api/health"
echo "  3. 如果仍有问题，查看日志: docker logs portal-frontend --tail 30"
