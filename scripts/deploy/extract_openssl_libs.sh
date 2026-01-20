#!/bin/bash

# ============================================================
# 从 Alpine 3.18 容器中提取 OpenSSL 1.1 库文件
# 这是一个备用方案，如果无法下载 APK 包
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== 从 Alpine 3.18 提取 OpenSSL 1.1 库文件 ===${NC}"
echo ""

FIX_DIR="./openssl-fix"
mkdir -p "$FIX_DIR"

# 启动临时容器（指定 x86_64 架构）
echo -e "${YELLOW}[1/4] 启动临时 Alpine 3.18 容器（x86_64）...${NC}"

# 尝试使用本地镜像或拉取
if docker images | grep -q "alpine.*3.18"; then
    echo "使用本地 Alpine 3.18 镜像"
    CONTAINER_ID=$(docker run --platform linux/amd64 -d alpine:3.18 sh -c "sleep 3600")
else
    echo "尝试拉取镜像（可能需要一些时间）..."
    # 尝试多个镜像源
    docker pull --platform linux/amd64 alpine:3.18 2>&1 || \
    docker pull --platform linux/amd64 docker.io/library/alpine:3.18 2>&1 || \
    echo "镜像拉取失败，尝试使用本地镜像..."
    
    CONTAINER_ID=$(docker run --platform linux/amd64 -d alpine:3.18 sh -c "sleep 3600" 2>&1)
fi

if [ -z "$CONTAINER_ID" ]; then
    echo -e "${RED}✗ 无法启动容器${NC}"
    exit 1
fi

echo "容器 ID: $CONTAINER_ID"

# 尝试安装多个可能的包
echo -e "${YELLOW}[2/4] 尝试安装 OpenSSL 1.1 包...${NC}"
PACKAGES=("openssl1.1" "openssl1.1-compat" "openssl1.1-libs")

INSTALLED=false
for PKG in "${PACKAGES[@]}"; do
    echo "尝试安装: $PKG"
    docker exec $CONTAINER_ID apk add --no-cache $PKG >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ $PKG 安装成功"
        INSTALLED=true
        
        # 检查已安装的文件
        echo "已安装的文件:"
        docker exec $CONTAINER_ID apk info -L $PKG 2>/dev/null | grep -E "(libssl|libcrypto)" | head -10
        break
    else
        echo "✗ $PKG 安装失败"
    fi
done

if [ "$INSTALLED" = false ]; then
    echo -e "${RED}✗ 所有包安装失败${NC}"
    docker rm -f $CONTAINER_ID >/dev/null 2>&1
    exit 1
fi

echo "等待文件系统同步..."
sleep 2

# 查找库文件
echo -e "${YELLOW}[3/4] 查找库文件...${NC}"

# 先检查常见位置
LIBSSL=$(docker exec $CONTAINER_ID ls /usr/lib/libssl.so.1.1 2>/dev/null | head -1)
LIBCRYPTO=$(docker exec $CONTAINER_ID ls /usr/lib/libcrypto.so.1.1 2>/dev/null | head -1)

# 如果没找到，搜索整个文件系统
if [ -z "$LIBSSL" ]; then
    echo "搜索整个文件系统..."
    LIBSSL=$(docker exec $CONTAINER_ID find / -name "libssl.so.1.1" -type f 2>/dev/null | grep -v "^/proc" | grep -v "^/sys" | head -1)
    LIBCRYPTO=$(docker exec $CONTAINER_ID find / -name "libcrypto.so.1.1" -type f 2>/dev/null | grep -v "^/proc" | grep -v "^/sys" | head -1)
fi

# 如果还是没找到，检查符号链接
if [ -z "$LIBSSL" ]; then
    echo "检查符号链接..."
    LIBSSL_LINK=$(docker exec $CONTAINER_ID find /usr/lib -name "libssl.so*" -type l 2>/dev/null | head -1)
    if [ -n "$LIBSSL_LINK" ]; then
        LIBSSL=$(docker exec $CONTAINER_ID readlink -f $LIBSSL_LINK 2>/dev/null)
    fi
    
    LIBCRYPTO_LINK=$(docker exec $CONTAINER_ID find /usr/lib -name "libcrypto.so*" -type l 2>/dev/null | head -1)
    if [ -n "$LIBCRYPTO_LINK" ]; then
        LIBCRYPTO=$(docker exec $CONTAINER_ID readlink -f $LIBCRYPTO_LINK 2>/dev/null)
    fi
fi

# 显示调试信息
echo "调试信息:"
echo "所有 libssl 文件:"
docker exec $CONTAINER_ID find /usr/lib -name "*ssl*" 2>/dev/null
echo "所有 libcrypto 文件:"
docker exec $CONTAINER_ID find /usr/lib -name "*crypto*" 2>/dev/null

if [ -n "$LIBSSL" ]; then
    echo -e "${GREEN}✓ 找到库文件: $LIBSSL${NC}"
    
    # 检查是否是符号链接
    if docker exec $CONTAINER_ID test -L "$LIBSSL" 2>/dev/null; then
        echo "发现符号链接，查找实际文件..."
        # 符号链接通常指向 ../../lib/libssl.so.1.1，实际文件在 /lib/
        LIBSSL_REAL="/lib/libssl.so.1.1"
        LIBCRYPTO_REAL="/lib/libcrypto.so.1.1"
        
        # 验证实际文件存在
        if docker exec $CONTAINER_ID test -f "$LIBSSL_REAL" 2>/dev/null; then
            LIBSSL="$LIBSSL_REAL"
            echo "使用实际文件: $LIBSSL"
        fi
        if [ -n "$LIBCRYPTO" ] && docker exec $CONTAINER_ID test -f "$LIBCRYPTO_REAL" 2>/dev/null; then
            LIBCRYPTO="$LIBCRYPTO_REAL"
        fi
    fi
    
    # 复制库文件（直接从 /lib 目录复制实际文件）
    echo -e "${YELLOW}[4/4] 复制库文件...${NC}"
    
    # 优先从 /lib 复制（实际文件位置）
    if docker exec $CONTAINER_ID test -f "/lib/libssl.so.1.1" 2>/dev/null; then
        docker cp $CONTAINER_ID:/lib/libssl.so.1.1 "$FIX_DIR/libssl.so.1.1"
        echo -e "${GREEN}✓ 从 /lib 复制 libssl.so.1.1${NC}"
    elif docker exec $CONTAINER_ID test -f "$LIBSSL" 2>/dev/null; then
        docker cp $CONTAINER_ID:$LIBSSL "$FIX_DIR/libssl.so.1.1"
        echo -e "${GREEN}✓ 复制 libssl.so.1.1${NC}"
    fi
    
    if docker exec $CONTAINER_ID test -f "/lib/libcrypto.so.1.1" 2>/dev/null; then
        docker cp $CONTAINER_ID:/lib/libcrypto.so.1.1 "$FIX_DIR/libcrypto.so.1.1"
        echo -e "${GREEN}✓ 从 /lib 复制 libcrypto.so.1.1${NC}"
    elif [ -n "$LIBCRYPTO" ] && docker exec $CONTAINER_ID test -f "$LIBCRYPTO" 2>/dev/null; then
        docker cp $CONTAINER_ID:$LIBCRYPTO "$FIX_DIR/libcrypto.so.1.1"
        echo -e "${GREEN}✓ 复制 libcrypto.so.1.1${NC}"
    fi
    
    # 验证文件
    if [ -f "$FIX_DIR/libssl.so.1.1" ] && [ ! -L "$FIX_DIR/libssl.so.1.1" ]; then
        FILE_SIZE=$(stat -f%z "$FIX_DIR/libssl.so.1.1" 2>/dev/null || stat -c%s "$FIX_DIR/libssl.so.1.1" 2>/dev/null)
        if [ "$FILE_SIZE" -gt 100000 ]; then  # 库文件应该大于 100KB
            echo -e "${GREEN}✓ libssl.so.1.1 已复制 ($(ls -lh "$FIX_DIR/libssl.so.1.1" | awk '{print $5}'))${NC}"
        else
            echo -e "${YELLOW}⚠ libssl.so.1.1 文件大小异常: ${FILE_SIZE} 字节${NC}"
        fi
    fi
    
    if [ -f "$FIX_DIR/libcrypto.so.1.1" ] && [ ! -L "$FIX_DIR/libcrypto.so.1.1" ]; then
        FILE_SIZE=$(stat -f%z "$FIX_DIR/libcrypto.so.1.1" 2>/dev/null || stat -c%s "$FIX_DIR/libcrypto.so.1.1" 2>/dev/null)
        if [ "$FILE_SIZE" -gt 100000 ]; then
            echo -e "${GREEN}✓ libcrypto.so.1.1 已复制 ($(ls -lh "$FIX_DIR/libcrypto.so.1.1" | awk '{print $5}'))${NC}"
        else
            echo -e "${YELLOW}⚠ libcrypto.so.1.1 文件大小异常: ${FILE_SIZE} 字节${NC}"
        fi
    fi
    
    # 创建安装脚本
    cat > "$FIX_DIR/install_libs.sh" << 'EOF'
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
docker cp libssl.so.1.1 portal-frontend:/usr/lib/
docker cp libcrypto.so.1.1 portal-frontend:/usr/lib/

echo "设置权限..."
docker exec -u 0 portal-frontend chmod 755 /usr/lib/libssl.so.1.1 /usr/lib/libcrypto.so.1.1

echo "验证库文件..."
docker exec portal-frontend ls -lh /usr/lib/libssl.so.1.1 /usr/lib/libcrypto.so.1.1

echo "重启容器..."
docker restart portal-frontend

echo ""
echo -e "${GREEN}✓ 安装完成!${NC}"
echo "请访问 http://<服务器IP>/api/health 验证"
EOF
    chmod +x "$FIX_DIR/install_libs.sh"
    
    echo ""
    echo -e "${GREEN}✓ 库文件已提取到 $FIX_DIR/${NC}"
    echo ""
    echo "使用方法:"
    echo "  cd openssl-fix"
    echo "  ./install_libs.sh"
else
    echo -e "${RED}✗ 未找到库文件${NC}"
    echo ""
    echo "已安装的包:"
    docker exec $CONTAINER_ID apk list --installed | grep openssl
fi

# 清理
echo "清理临时容器..."
docker rm -f $CONTAINER_ID >/dev/null 2>&1

echo ""
echo "完成!"
