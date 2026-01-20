#!/bin/bash

# ============================================================
# 验证修复结果
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 验证 OpenSSL 修复结果 ===${NC}"
echo ""

# 1. 检查容器状态
echo -e "${YELLOW}[1/5] 检查容器状态...${NC}"
if docker ps --format '{{.Names}}' | grep -q "portal-frontend"; then
    echo -e "${GREEN}✓ 容器正在运行${NC}"
    docker ps | grep portal-frontend
else
    echo -e "${RED}✗ 容器未运行${NC}"
    exit 1
fi

# 2. 检查库文件
echo ""
echo -e "${YELLOW}[2/5] 检查库文件...${NC}"
if docker exec portal-frontend test -f /lib/libssl.so.1.1 2>/dev/null; then
    echo -e "${GREEN}✓ /lib/libssl.so.1.1 存在${NC}"
    docker exec portal-frontend ls -lh /lib/libssl.so.1.1
else
    echo -e "${RED}✗ /lib/libssl.so.1.1 不存在${NC}"
fi

if docker exec portal-frontend test -f /lib/libcrypto.so.1.1 2>/dev/null; then
    echo -e "${GREEN}✓ /lib/libcrypto.so.1.1 存在${NC}"
    docker exec portal-frontend ls -lh /lib/libcrypto.so.1.1
else
    echo -e "${RED}✗ /lib/libcrypto.so.1.1 不存在${NC}"
fi

# 3. 检查库文件依赖
echo ""
echo -e "${YELLOW}[3/5] 检查库文件依赖...${NC}"
MISSING_DEPS=$(docker exec portal-frontend ldd /lib/libssl.so.1.1 2>&1 | grep "not found" || echo "")
if [ -z "$MISSING_DEPS" ]; then
    echo -e "${GREEN}✓ 库文件依赖完整${NC}"
else
    echo -e "${RED}✗ 缺少依赖: $MISSING_DEPS${NC}"
fi

# 4. 检查 Prisma 引擎
echo ""
echo -e "${YELLOW}[4/5] 检查 Prisma 引擎库文件加载...${NC}"
PRISMA_LDD=$(docker exec portal-frontend sh -c "ldd /app/node_modules/.prisma/client/libquery_engine-linux-musl.so.node 2>&1 | grep libssl" || echo "")
if echo "$PRISMA_LDD" | grep -q "/lib/libssl.so.1.1"; then
    echo -e "${GREEN}✓ Prisma 引擎可以找到 libssl.so.1.1${NC}"
    echo "  $PRISMA_LDD"
else
    echo -e "${YELLOW}⚠ Prisma 引擎库文件检查:${NC}"
    echo "  $PRISMA_LDD"
fi

# 5. 检查健康检查和最新日志
echo ""
echo -e "${YELLOW}[5/5] 检查健康检查和最新日志...${NC}"
HEALTH_RESPONSE=$(docker exec geely-gateway curl -s http://portal-frontend:3000/api/health 2>/dev/null || echo "")
if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    echo -e "${GREEN}✓ 健康检查正常${NC}"
    echo "  响应: $HEALTH_RESPONSE"
else
    echo -e "${YELLOW}⚠ 健康检查响应: $HEALTH_RESPONSE${NC}"
fi

# 检查最新日志（只检查最近启动后的日志）
echo ""
echo "最新应用日志（最后 5 行）:"
docker logs portal-frontend --tail 5

# 检查是否有新的 SSL 错误（只检查最近 1 分钟）
RECENT_ERRORS=$(docker logs portal-frontend --since 1m 2>&1 | grep -i "libssl\|No such file" || echo "")
if [ -z "$RECENT_ERRORS" ]; then
    echo -e "${GREEN}✓ 最近无 SSL 相关错误${NC}"
else
    echo -e "${YELLOW}⚠ 最近有 SSL 错误:${NC}"
    echo "$RECENT_ERRORS"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  验证完成${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "如果健康检查返回 'healthy'，说明修复成功！"
echo "日志中的旧错误是修复之前的记录，可以忽略。"
