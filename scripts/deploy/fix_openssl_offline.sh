#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Portal OpenSSL 兼容性修复 (离线/内网环境) ===${NC}"
echo ""

# 检查容器是否运行
if ! docker ps --format '{{.Names}}' | grep -q "portal-frontend"; then
    echo -e "${RED}✗ 错误: portal-frontend 容器未运行${NC}"
    echo "请先执行: docker-compose up -d"
    exit 1
fi

echo -e "${YELLOW}请选择修复方案:${NC}"
echo "  1) 配置阿里云镜像源 (推荐，需要能访问阿里云)"
echo "  2) 配置清华大学镜像源"
echo "  3) 离线安装 openssl1.1-compat (需要提前准备 .apk 文件)"
echo "  4) 重建镜像 (将 openssl1.1-compat 内置到镜像中)"
echo ""
read -p "请输入选项 [1-4]: " choice

case $choice in
    1)
        echo -e "${YELLOW}配置阿里云镜像源...${NC}"
        docker exec -u 0 portal-frontend sh -c "sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories"
        docker exec -u 0 portal-frontend cat /etc/apk/repositories
        echo -e "${GREEN}✓ 镜像源已切换到阿里云${NC}"
        echo ""
        echo "尝试安装 openssl1.1-compat..."
        docker exec -u 0 portal-frontend apk update
        docker exec -u 0 portal-frontend apk add --no-cache openssl1.1-compat
        ;;
    2)
        echo -e "${YELLOW}配置清华大学镜像源...${NC}"
        docker exec -u 0 portal-frontend sh -c "sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories"
        docker exec -u 0 portal-frontend cat /etc/apk/repositories
        echo -e "${GREEN}✓ 镜像源已切换到清华大学${NC}"
        echo ""
        echo "尝试安装 openssl1.1-compat..."
        docker exec -u 0 portal-frontend apk update
        docker exec -u 0 portal-frontend apk add --no-cache openssl1.1-compat
        ;;
    3)
        echo -e "${YELLOW}离线安装模式...${NC}"
        if [ ! -f "./openssl1.1-compat.apk" ]; then
            echo -e "${RED}✗ 错误: 未找到 openssl1.1-compat.apk 文件${NC}"
            echo ""
            echo "请执行以下步骤准备离线安装包："
            echo "1. 在有网络的机器上下载:"
            echo "   wget https://dl-cdn.alpinelinux.org/alpine/v3.19/main/x86_64/openssl1.1-compat-1.1.1w-r1.apk"
            echo ""
            echo "2. 将 .apk 文件上传到当前目录"
            echo "3. 重命名为: openssl1.1-compat.apk"
            exit 1
        fi
        
        echo "正在复制安装包到容器..."
        docker cp ./openssl1.1-compat.apk portal-frontend:/tmp/
        echo "正在安装..."
        docker exec -u 0 portal-frontend apk add --allow-untrusted /tmp/openssl1.1-compat.apk
        docker exec -u 0 portal-frontend rm /tmp/openssl1.1-compat.apk
        ;;
    4)
        echo -e "${YELLOW}准备重建镜像...${NC}"
        echo ""
        echo "此方案需要修改 Dockerfile 并重新构建镜像。"
        echo "步骤："
        echo "  1. 在 portal 项目的 Dockerfile 中添加:"
        echo "     RUN apk add --no-cache openssl1.1-compat"
        echo ""
        echo "  2. 重新构建镜像:"
        echo "     docker build -t unified-portal-frontend:v1.0 ."
        echo ""
        echo "  3. 重新导出并上传到云服务器"
        echo ""
        echo "是否自动生成 Dockerfile 补丁? (y/n)"
        read -p "> " create_patch
        
        if [ "$create_patch" == "y" ]; then
            cat > ./portal_dockerfile_patch.txt << 'EOF'
# 在 Dockerfile 的 RUN 指令中添加 openssl1.1-compat
# 找到类似这样的行:
#   RUN apk add --no-cache libc6-compat
# 修改为:
#   RUN apk add --no-cache libc6-compat openssl1.1-compat

# 或者在最后添加单独的层:
RUN apk add --no-cache openssl1.1-compat
EOF
            echo -e "${GREEN}✓ 已生成 portal_dockerfile_patch.txt${NC}"
        fi
        exit 0
        ;;
    *)
        echo -e "${RED}无效选项${NC}"
        exit 1
        ;;
esac

# 验证安装
echo ""
echo -e "${YELLOW}验证 OpenSSL 1.1 库...${NC}"
docker exec portal-frontend ls -l /usr/lib/libssl.so.1.1 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ libssl.so.1.1 存在${NC}"
else
    echo -e "${RED}✗ libssl.so.1.1 不存在${NC}"
    exit 1
fi

# 重启容器
echo ""
echo -e "${YELLOW}重启 portal-frontend 容器...${NC}"
docker restart portal-frontend
echo "等待容器启动..."
sleep 5

# 验证健康检查
echo ""
echo -e "${YELLOW}验证健康检查接口...${NC}"
HEALTH_CODE=$(docker exec geely-gateway curl -s -o /dev/null -w "%{http_code}" http://portal-frontend:3000/api/health 2>/dev/null)
if [ "$HEALTH_CODE" == "200" ]; then
    echo -e "${GREEN}✓ 健康检查接口: 200 OK${NC}"
    echo -e "${GREEN}✓✓✓ 修复成功! ✓✓✓${NC}"
else
    echo -e "${YELLOW}⚠ 健康检查接口: $HEALTH_CODE${NC}"
    echo "如果仍然失败，请查看容器日志:"
    echo "  docker logs portal-frontend"
fi

echo ""
echo "完成时间: $(date)"
