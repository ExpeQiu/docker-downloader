#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Unified Portal 问题修复脚本 ===${NC}"
echo "开始时间: $(date)"
echo ""

# 1. 修复 Unified Portal OpenSSL 问题
echo -e "${YELLOW}[1/4] 修复 Unified Portal OpenSSL 兼容性...${NC}"
if docker ps --format '{{.Names}}' | grep -q "portal-frontend"; then
    docker exec -u 0 portal-frontend apk add --no-cache openssl1.1-compat 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ OpenSSL 兼容包安装成功${NC}"
        docker restart portal-frontend
        echo -e "${GREEN}✓ 容器已重启${NC}"
    else
        echo -e "${YELLOW}⚠ OpenSSL 兼容包已存在或安装失败${NC}"
    fi
else
    echo -e "${RED}✗ portal-frontend 容器未运行${NC}"
fi
echo ""

# 2. 验证 Nginx 配置
echo -e "${YELLOW}[2/4] 验证 Nginx 配置语法...${NC}"
if docker ps --format '{{.Names}}' | grep -q "geely-gateway"; then
    docker exec geely-gateway nginx -t
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Nginx 配置语法正确${NC}"
    else
        echo -e "${RED}✗ Nginx 配置有错误，请检查 nginx/default.conf${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ geely-gateway 容器未运行${NC}"
    exit 1
fi
echo ""

# 3. 重载 Nginx 配置
echo -e "${YELLOW}[3/4] 重载 Nginx 配置...${NC}"
docker exec geely-gateway nginx -s reload
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Nginx 配置重载成功${NC}"
else
    echo -e "${RED}✗ Nginx 重载失败${NC}"
fi
echo ""

# 4. 验证服务健康状态
echo -e "${YELLOW}[4/4] 验证服务状态...${NC}"
sleep 3

# 获取服务器 IP (容器内访问)
echo "检查健康接口..."
HEALTH_CODE=$(docker exec geely-gateway curl -s -o /dev/null -w "%{http_code}" http://portal-frontend:3000/api/health 2>/dev/null)
if [ "$HEALTH_CODE" == "200" ]; then
    echo -e "${GREEN}✓ 健康检查接口: 200 OK${NC}"
else
    echo -e "${RED}✗ 健康检查接口: $HEALTH_CODE${NC}"
fi

echo ""
echo -e "${GREEN}=== 修复完成 ===${NC}"
echo ""
echo "验证建议:"
echo "  1. 访问 http://<IP>/api/health 确认返回 200"
echo "  2. 访问 http://<IP>/tpd2/ 确认页面加载正常"
echo "  3. 访问 http://<IP>/writer/ 确认静态资源加载"
echo "  4. 访问 http://<IP>/todify/ 确认静态资源加载"
