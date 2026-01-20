#!/bin/bash

# ============================================================
# 直接下载并提取 OpenSSL 1.1 库文件（x86_64）
# 无需 Docker，直接从 Alpine 包仓库下载
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIX_DIR="$SCRIPT_DIR/openssl-fix"
mkdir -p "$FIX_DIR"

echo -e "${GREEN}=== 下载 OpenSSL 1.1 库文件（x86_64）===${NC}"
echo ""

# 下载 APK 包（openssl1.1 主包包含库文件）
echo -e "${YELLOW}[1/3] 下载 openssl1.1 APK（包含库文件）...${NC}"

# 尝试多个可能的包名和版本
PACKAGES=(
    "https://mirrors.aliyun.com/alpine/v3.18/main/x86_64/openssl1.1-1.1.1u-r1.apk"
    "https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.18/main/x86_64/openssl1.1-1.1.1u-r1.apk"
    "https://dl-cdn.alpinelinux.org/alpine/v3.18/main/x86_64/openssl1.1-1.1.1u-r1.apk"
)

TMP_APK="/tmp/openssl1.1.apk"
DOWNLOADED=false

for APK_URL in "${PACKAGES[@]}"; do
    echo "尝试: $APK_URL"
    if command -v wget &> /dev/null; then
        wget -q "$APK_URL" -O "$TMP_APK" 2>/dev/null
    elif command -v curl &> /dev/null; then
        curl -fsSL "$APK_URL" -o "$TMP_APK" 2>/dev/null
    fi
    
    if [ -f "$TMP_APK" ] && [ -s "$TMP_APK" ]; then
        # 验证包是否包含库文件
        if gunzip -c "$TMP_APK" 2>/dev/null | tar -tf - 2>/dev/null | grep -qE "(lib/libssl|lib/libcrypto|usr/lib/libssl|usr/lib/libcrypto)"; then
            DOWNLOADED=true
            break
        else
            echo "此包不包含库文件，继续尝试..."
            rm -f "$TMP_APK"
        fi
    fi
done

if command -v wget &> /dev/null; then
    wget -q "$APK_URL" -O "$TMP_APK"
elif command -v curl &> /dev/null; then
    curl -fsSL "$APK_URL" -o "$TMP_APK"
else
    echo -e "${RED}✗ 未找到 wget 或 curl${NC}"
    exit 1
fi

if [ "$DOWNLOADED" = false ] || [ ! -f "$TMP_APK" ] || [ ! -s "$TMP_APK" ]; then
    echo -e "${RED}✗ 下载失败或包不包含库文件${NC}"
    echo ""
    echo "请手动下载 openssl1.1 主包（不是 openssl1.1-compat）:"
    echo "  wget https://mirrors.aliyun.com/alpine/v3.18/main/x86_64/openssl1.1-1.1.1u-r1.apk"
    exit 1
fi

echo -e "${GREEN}✓ 下载成功: $(ls -lh "$TMP_APK" | awk '{print $5}')${NC}"

# 解压 APK
echo -e "${YELLOW}[2/3] 解压 APK 并提取库文件...${NC}"
TMP_DIR="/tmp/extract_openssl_$$"
mkdir -p "$TMP_DIR"

cd "$TMP_DIR"
gunzip -c "$TMP_APK" | tar -xf - 2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 解压失败${NC}"
    rm -rf "$TMP_DIR" "$TMP_APK"
    exit 1
fi

# 查找并复制库文件
LIBSSL=$(find "$TMP_DIR" -name "libssl.so.1.1" -type f 2>/dev/null | head -1)
LIBCRYPTO=$(find "$TMP_DIR" -name "libcrypto.so.1.1" -type f 2>/dev/null | head -1)

if [ -z "$LIBSSL" ]; then
    # 尝试从 /lib 目录查找
    LIBSSL="$TMP_DIR/lib/libssl.so.1.1"
    LIBCRYPTO="$TMP_DIR/lib/libcrypto.so.1.1"
fi

if [ -f "$LIBSSL" ] && [ -f "$LIBCRYPTO" ]; then
    cp "$LIBSSL" "$FIX_DIR/libssl.so.1.1"
    cp "$LIBCRYPTO" "$FIX_DIR/libcrypto.so.1.1"
    
    echo -e "${GREEN}✓ 库文件已提取${NC}"
    
    # 验证架构
    echo -e "${YELLOW}[3/3] 验证文件架构...${NC}"
    ARCH=$(file "$FIX_DIR/libssl.so.1.1" | grep -o "x86-64\|ARM\|aarch64")
    
    if echo "$ARCH" | grep -q "x86-64"; then
        echo -e "${GREEN}✓ 架构正确: x86-64${NC}"
        echo -e "${GREEN}✓ libssl.so.1.1: $(ls -lh "$FIX_DIR/libssl.so.1.1" | awk '{print $5}')${NC}"
        echo -e "${GREEN}✓ libcrypto.so.1.1: $(ls -lh "$FIX_DIR/libcrypto.so.1.1" | awk '{print $5}')${NC}"
    else
        echo -e "${RED}✗ 架构错误: $ARCH（需要 x86-64）${NC}"
        rm -f "$FIX_DIR/libssl.so.1.1" "$FIX_DIR/libcrypto.so.1.1"
        rm -rf "$TMP_DIR" "$TMP_APK"
        exit 1
    fi
else
    echo -e "${RED}✗ 未找到库文件${NC}"
    echo "APK 内容:"
    find "$TMP_DIR" -type f | head -10
    rm -rf "$TMP_DIR" "$TMP_APK"
    exit 1
fi

# 清理
rm -rf "$TMP_DIR" "$TMP_APK"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  完成!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "库文件已提取到: $FIX_DIR/"
echo ""
echo "下一步:"
echo "  1. cd $SCRIPT_DIR"
echo "  2. tar -cvf openssl-fix.tar openssl-fix/"
echo "  3. 上传 openssl-fix.tar 到服务器"
echo "  4. 在服务器上执行: tar -xvf openssl-fix.tar && cd openssl-fix && ./install_libs.sh"
