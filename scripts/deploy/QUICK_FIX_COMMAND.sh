#!/bin/bash

# ============================================================
# 快速修复命令 - 在企业内部云服务器执行
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== OpenSSL 修复 - 快速执行 ===${NC}"
echo ""

# 检查是否在 openssl-fix 目录
if [ ! -f "libssl.so.1.1" ] && [ ! -f "install_libs.sh" ]; then
    if [ -f "openssl-fix.tar" ]; then
        echo "解压修复包..."
        tar -xvf openssl-fix.tar
        cd openssl-fix
    else
        echo -e "${RED}✗ 未找到修复包文件${NC}"
        echo "请确保 openssl-fix.tar 在当前目录"
        exit 1
    fi
fi

# 检查容器
if ! docker ps --format '{{.Names}}' | grep -q "portal-frontend"; then
    echo -e "${RED}✗ portal-frontend 容器未运行${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/4] 检查当前库文件...${NC}"
docker exec portal-frontend ls -lh /lib/libssl.so.1.1 /usr/lib/libssl.so.1.1 2>/dev/null || echo "库文件不存在，需要安装"

# 安装库文件到 /lib 目录
echo -e "${YELLOW}[2/4] 安装库文件到 /lib 目录...${NC}"

if [ -f "libssl.so.1.1" ] && [ -f "libcrypto.so.1.1" ]; then
    # 从本地文件复制
    echo "从本地文件复制..."
    docker cp libssl.so.1.1 portal-frontend:/lib/
    docker cp libcrypto.so.1.1 portal-frontend:/lib/
    docker exec -u 0 portal-frontend chmod 755 /lib/libssl.so.1.1 /lib/libcrypto.so.1.1
    echo -e "${GREEN}✓ 库文件已复制到 /lib${NC}"
elif docker exec portal-frontend test -f /usr/lib/libssl.so.1.1 2>/dev/null; then
    # 从 /usr/lib 复制到 /lib
    echo "从 /usr/lib 复制到 /lib..."
    docker exec -u 0 portal-frontend cp /usr/lib/libssl.so.1.1 /lib/
    docker exec -u 0 portal-frontend cp /usr/lib/libcrypto.so.1.1 /lib/
    docker exec -u 0 portal-frontend chmod 755 /lib/libssl.so.1.1 /lib/libcrypto.so.1.1
    echo -e "${GREEN}✓ 库文件已复制到 /lib${NC}"
else
    echo -e "${RED}✗ 未找到库文件${NC}"
    echo "请先运行: ./install_libs.sh"
    exit 1
fi

# 验证库文件
echo -e "${YELLOW}[3/4] 验证库文件...${NC}"
docker exec portal-frontend ls -lh /lib/libssl.so.1.1 /lib/libcrypto.so.1.1

# 重启容器
echo -e "${YELLOW}[4/4] 重启容器...${NC}"
docker restart portal-frontend

echo "等待容器启动（15秒）..."
sleep 15

# 验证修复
echo ""
echo -e "${GREEN}=== 验证修复结果 ===${NC}"

# 检查容器状态
if docker ps --format '{{.Names}}' | grep -q "portal-frontend"; then
    echo -e "${GREEN}✓ 容器正在运行${NC}"
else
    echo -e "${RED}✗ 容器启动失败${NC}"
    docker logs portal-frontend --tail 20
    exit 1
fi

# 检查日志
echo ""
echo "检查应用日志（最后 10 行）:"
docker logs portal-frontend --tail 10

# 检查 SSL 错误
SSL_ERROR=$(docker logs portal-frontend 2>&1 | grep -i "libssl\|No such file" | tail -1 || echo "")
if [ -z "$SSL_ERROR" ]; then
    echo -e "${GREEN}✓ 无 SSL 相关错误${NC}"
else
    echo -e "${YELLOW}⚠ 仍有 SSL 错误: $SSL_ERROR${NC}"
fi

# 检查健康检查
echo ""
echo "检查健康检查接口:"
HEALTH_RESPONSE=$(docker exec geely-gateway curl -s http://portal-frontend:3000/api/health 2>/dev/null || echo "")
if [ -n "$HEALTH_RESPONSE" ]; then
    echo -e "${GREEN}✓ 健康检查响应: $HEALTH_RESPONSE${NC}"
else
    echo -e "${YELLOW}⚠ 健康检查无响应，可能需要更多时间启动${NC}"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  修复完成！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "请访问以下地址验证:"
echo "  http://<服务器IP>/api/health"
echo ""
echo "如果仍有问题，请查看日志:"
echo "  docker logs portal-frontend --tail 50"
