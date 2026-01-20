#!/bin/bash

# ============================================================
# 本地执行：创建 OpenSSL 离线修复包
# 生成 openssl-fix.tar 用于上传到云服务器
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIX_DIR="$SCRIPT_DIR/openssl-fix"
APK_FILE="$FIX_DIR/openssl1.1-compat.apk"

echo -e "${GREEN}=== 创建 OpenSSL 离线修复包 ===${NC}"
echo ""

# 检查目录
if [ ! -d "$FIX_DIR" ]; then
    echo -e "${RED}错误: openssl-fix 目录不存在${NC}"
    exit 1
fi

# 下载 openssl1.1 相关包（包含 libssl.so.1.1 和 libcrypto.so.1.1）
echo -e "${YELLOW}[1/3] 下载 openssl1.1 包（包含库文件）...${NC}"

# Alpine 版本和架构
ALPINE_VERSION="v3.18"
ARCH="x86_64"
PACKAGE_VERSION="1.1.1u-r1"

# 尝试多个镜像源和包名
MIRRORS=(
    "https://mirrors.aliyun.com/alpine"
    "https://mirrors.tuna.tsinghua.edu.cn/alpine"
    "https://dl-cdn.alpinelinux.org/alpine"
)

# 尝试多个可能的包名（按优先级排序）
# 在 Alpine 3.18 中，openssl1.1 主包应该包含库文件
PACKAGES=(
    "main/x86_64/openssl1.1-${PACKAGE_VERSION}.apk"
    "main/x86_64/openssl1.1-libs-${PACKAGE_VERSION}.apk"
    "community/x86_64/openssl1.1-compat-${PACKAGE_VERSION}.apk"
)

DOWNLOAD_SUCCESS=false
LIBS_FILE="$FIX_DIR/openssl1.1-libs.apk"

for MIRROR in "${MIRRORS[@]}"; do
    for PKG_PATH in "${PACKAGES[@]}"; do
        URL="${MIRROR}/${ALPINE_VERSION}/${PKG_PATH}"
        echo "尝试下载: $URL"
        
        # 先检查 URL 是否存在
        if command -v curl &> /dev/null; then
            HTTP_CODE=$(curl -sL -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
            if [ "$HTTP_CODE" != "200" ]; then
                echo "  HTTP $HTTP_CODE - 跳过"
                continue
            fi
            curl -fsSL "$URL" -o "$LIBS_FILE" 2>&1
        elif command -v wget &> /dev/null; then
            wget -q --spider "$URL" 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "  文件不存在 - 跳过"
                continue
            fi
            wget -q "$URL" -O "$LIBS_FILE" 2>&1
        fi
        
        if [ -f "$LIBS_FILE" ] && [ -s "$LIBS_FILE" ]; then
            FILE_SIZE=$(stat -f%z "$LIBS_FILE" 2>/dev/null || stat -c%s "$LIBS_FILE" 2>/dev/null)
            if [ "$FILE_SIZE" -gt 10000 ]; then  # 至少 10KB
                # 验证文件是否包含库文件
                echo "  验证包内容..."
                TAR_CONTENT=$(gunzip -c "$LIBS_FILE" 2>/dev/null | tar -tf - 2>/dev/null)
                if echo "$TAR_CONTENT" | grep -qE "(libssl\.so\.1\.1|libcrypto\.so\.1\.1|usr/lib/libssl|usr/lib/libcrypto|lib/libssl|lib/libcrypto)"; then
                    echo -e "${GREEN}✓ 下载成功: $(ls -lh "$LIBS_FILE" | awk '{print $5}')${NC}"
                    echo -e "${GREEN}✓ 包包含库文件${NC}"
                    echo "  包内容预览:"
                    echo "$TAR_CONTENT" | grep -E "(libssl|libcrypto)" | head -5
                    DOWNLOAD_SUCCESS=true
                    break 2
                else
                    echo "  此包不包含库文件，继续尝试..."
                    rm -f "$LIBS_FILE"
                fi
            else
                echo "  文件太小 ($FILE_SIZE 字节)，可能下载失败，继续尝试..."
                rm -f "$LIBS_FILE"
            fi
        else
            echo "  下载失败，继续尝试..."
        fi
    done
done

if [ "$DOWNLOAD_SUCCESS" = false ]; then
    echo -e "${RED}✗ 所有包下载失败${NC}"
    echo ""
    echo "请手动下载以下包之一（包含库文件的）:"
    echo "  1. https://mirrors.aliyun.com/alpine/v3.18/main/x86_64/openssl1.1-${PACKAGE_VERSION}.apk"
    echo "  2. https://mirrors.aliyun.com/alpine/v3.18/main/x86_64/openssl1.1-libs-${PACKAGE_VERSION}.apk"
    echo ""
    echo "下载后重命名为 openssl1.1-compat.apk 放到 openssl-fix 目录"
    exit 1
fi

# 重命名为主文件（保持兼容性）
mv "$LIBS_FILE" "$APK_FILE" 2>/dev/null || cp "$LIBS_FILE" "$APK_FILE"
echo -e "${GREEN}✓ 安装包准备完成${NC}"

# 验证文件
echo ""
echo -e "${YELLOW}[2/3] 验证文件完整性...${NC}"
echo "文件列表:"
ls -la "$FIX_DIR/"

# 打包
echo ""
echo -e "${YELLOW}[3/3] 打包成 tar 文件...${NC}"
cd "$SCRIPT_DIR"
# 确保 tar 文件可以创建
rm -f openssl-fix.tar
tar -cvf openssl-fix.tar openssl-fix/

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  打包完成!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "生成文件: $(ls -lh openssl-fix.tar | awk '{print $9, $5}')"
    echo ""
    echo -e "${YELLOW}下一步:${NC}"
    echo "  1. 将 openssl-fix.tar 上传到云服务器"
    echo "  2. 在服务器上执行:"
    echo "     tar -xvf openssl-fix.tar"
    echo "     cd openssl-fix"
    echo "     chmod +x fix.sh"
    echo "     ./fix.sh"
else
    echo -e "${RED}✗ 打包失败${NC}"
    exit 1
fi
