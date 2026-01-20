#!/bin/bash

# 在有网络的机器上运行此脚本，下载 openssl1.1-compat 离线安装包

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== 下载 OpenSSL 1.1 离线安装包 ===${NC}"
echo ""

# 检测 Alpine 版本 (默认使用 v3.19)
ALPINE_VERSION="v3.19"
ARCH="x86_64"

echo "目标 Alpine 版本: $ALPINE_VERSION"
echo "目标架构: $ARCH"
echo ""

# 下载主包
echo -e "${YELLOW}下载 openssl1.1-compat...${NC}"
wget https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/main/${ARCH}/openssl1.1-compat-1.1.1w-r1.apk \
    -O openssl1.1-compat.apk

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 下载成功: openssl1.1-compat.apk${NC}"
    ls -lh openssl1.1-compat.apk
else
    echo "主源下载失败，尝试镜像源..."
    
    # 尝试阿里云镜像
    wget https://mirrors.aliyun.com/alpine/${ALPINE_VERSION}/main/${ARCH}/openssl1.1-compat-1.1.1w-r1.apk \
        -O openssl1.1-compat.apk
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 从阿里云镜像下载成功${NC}"
    else
        echo -e "${YELLOW}阿里云镜像失败，尝试清华镜像...${NC}"
        wget https://mirrors.tuna.tsinghua.edu.cn/alpine/${ALPINE_VERSION}/main/${ARCH}/openssl1.1-compat-1.1.1w-r1.apk \
            -O openssl1.1-compat.apk
    fi
fi

echo ""
echo "================================================"
echo "下载完成！请将以下文件上传到云服务器:"
echo "  - openssl1.1-compat.apk"
echo ""
echo "然后在云服务器上执行:"
echo "  ./fix_openssl_offline.sh"
echo "  选择方案 3 (离线安装)"
echo "================================================"
