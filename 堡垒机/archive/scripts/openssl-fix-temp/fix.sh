#!/bin/bash

# ============================================================
# OpenSSL 1.1 离线修复脚本 (一键执行)
# 使用方法: 
#   1. 将整个 openssl-fix 目录上传到服务器
#   2. cd openssl-fix && chmod +x fix.sh && ./fix.sh
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Portal OpenSSL 1.1 离线修复 ===${NC}"
echo "时间: $(date)"
echo ""

# 检查容器是否运行
if ! docker ps --format '{{.Names}}' | grep -q "portal-frontend"; then
    echo -e "${RED}✗ 错误: portal-frontend 容器未运行${NC}"
    echo "请先执行: docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✓ portal-frontend 容器正在运行${NC}"

# 检查安装包是否存在
APK_FILE="openssl1.1-compat.apk"
if [ ! -f "$APK_FILE" ]; then
    echo -e "${RED}✗ 错误: 未找到 $APK_FILE${NC}"
    echo "请确保安装包与此脚本在同一目录"
    exit 1
fi
echo -e "${GREEN}✓ 找到安装包: $APK_FILE ($(ls -lh $APK_FILE | awk '{print $5}'))${NC}"
echo ""

# 检查容器 Alpine 版本
echo -e "${YELLOW}[0/4] 检查容器环境...${NC}"
ALPINE_VERSION=$(docker exec portal-frontend cat /etc/alpine-release 2>/dev/null || echo "未知")
echo "Alpine 版本: $ALPINE_VERSION"

# 复制并安装
echo -e "${YELLOW}[1/4] 复制安装包到容器...${NC}"
docker cp $APK_FILE portal-frontend:/tmp/
echo -e "${GREEN}✓ 复制完成${NC}"

echo -e "${YELLOW}[2/4] 安装 openssl1.1-compat (完全离线模式)...${NC}"

# 方法1: 修改 hosts 和 repositories，强制 apk 离线安装
echo "尝试方法1: 阻止 DNS 解析并清空 repositories..."
docker exec -u 0 portal-frontend sh -c "
    # 备份配置
    cp /etc/apk/repositories /etc/apk/repositories.bak 2>/dev/null
    cp /etc/hosts /etc/hosts.bak 2>/dev/null
    
    # 清空 repositories（强制离线）
    echo '# 临时禁用' > /etc/apk/repositories
    
    # 阻止 DNS 解析（将常用镜像源指向 127.0.0.1）
    echo '127.0.0.1 dl-cdn.alpinelinux.org' >> /etc/hosts
    echo '127.0.0.1 mirrors.aliyun.com' >> /etc/hosts
    echo '127.0.0.1 mirrors.tuna.tsinghua.edu.cn' >> /etc/hosts
    
    # 使用 timeout 快速失败（5秒超时）
    timeout 5 apk add --allow-untrusted --no-cache /tmp/$APK_FILE 2>&1 || \
    apk add --allow-untrusted --no-cache /tmp/$APK_FILE 2>&1 | head -20
    RESULT=\$?
    
    # 恢复配置
    mv /etc/apk/repositories.bak /etc/apk/repositories 2>/dev/null
    mv /etc/hosts.bak /etc/hosts 2>/dev/null
    
    exit \$RESULT
" 2>&1 | grep -v "fetch http" | grep -v "WARNING" | head -15

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 安装成功 (方法1: 禁用网络)${NC}"
else
    echo ""
    echo "方法1失败，尝试方法2: 使用 apk 的 --no-network 选项..."
    docker exec -u 0 portal-frontend sh -c "
        cp /etc/apk/repositories /etc/apk/repositories.bak 2>/dev/null
        echo '# 临时禁用' > /etc/apk/repositories
        apk add --allow-untrusted --no-cache --no-network /tmp/$APK_FILE 2>&1
        RESULT=\$?
        mv /etc/apk/repositories.bak /etc/apk/repositories 2>/dev/null
        exit \$RESULT
    " 2>&1 | grep -v "fetch http" | head -10
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 安装成功 (方法2: --no-network)${NC}"
    else
        echo ""
        echo "方法2失败，尝试方法3: 使用 apk extract 直接提取文件..."
        # 方法3: 使用 apk extract（不安装，只提取文件，不检查依赖）
        docker exec -u 0 portal-frontend sh -c "
            cd /tmp
            rm -rf /tmp/extract_apk 2>/dev/null
            mkdir -p /tmp/extract_apk
            
            # 清空 repositories 避免依赖检查
            cp /etc/apk/repositories /etc/apk/repositories.bak3 2>/dev/null
            echo '# 临时禁用' > /etc/apk/repositories
            
            # 使用 apk extract 提取所有文件（不检查依赖）
            apk extract --allow-untrusted --no-network $APK_FILE -C /tmp/extract_apk 2>&1 || \
            apk extract --allow-untrusted $APK_FILE -C /tmp/extract_apk 2>&1 | head -10
            
            # 恢复配置
            mv /etc/apk/repositories.bak3 /etc/apk/repositories 2>/dev/null
            
            # 查找库文件（可能在 usr/lib 或 lib 目录）
            LIBSSL=\$(find /tmp/extract_apk -name 'libssl.so.1.1' -type f 2>/dev/null | head -1)
            LIBCRYPTO=\$(find /tmp/extract_apk -name 'libcrypto.so.1.1' -type f 2>/dev/null | head -1)
            
            # 如果没找到，尝试查找所有 libssl/libcrypto
            if [ -z \"\$LIBSSL\" ]; then
                LIBSSL=\$(find /tmp/extract_apk -name 'libssl.so*' -type f 2>/dev/null | head -1)
            fi
            if [ -z \"\$LIBCRYPTO\" ]; then
                LIBCRYPTO=\$(find /tmp/extract_apk -name 'libcrypto.so*' -type f 2>/dev/null | head -1)
            fi
            
            if [ -n \"\$LIBSSL\" ] && [ -f \"\$LIBSSL\" ]; then
                mkdir -p /usr/lib
                cp -f \"\$LIBSSL\" /usr/lib/libssl.so.1.1
                [ -n \"\$LIBCRYPTO\" ] && cp -f \"\$LIBCRYPTO\" /usr/lib/libcrypto.so.1.1
                chmod 755 /usr/lib/libssl.so.1.1 2>/dev/null
                chmod 755 /usr/lib/libcrypto.so.1.1 2>/dev/null
                echo \"✓ 库文件已复制: \$LIBSSL -> /usr/lib/libssl.so.1.1\"
                exit 0
            else
                echo '✗ 未找到库文件'
                echo 'extract_apk 目录结构:'
                find /tmp/extract_apk -type d 2>/dev/null
                echo 'extract_apk 所有文件:'
                find /tmp/extract_apk -type f 2>/dev/null | head -20
                exit 1
            fi
        " 2>&1 | grep -v "^$"
        
        if [ $? -ne 0 ]; then
            echo ""
            echo "方法3失败，尝试方法4: 手动解析 APK 文件格式..."
            # 方法4: 手动解析 APK 文件，提取所有数据块
            docker exec -u 0 portal-frontend sh -c "
                cd /tmp
                rm -rf /tmp/extract_apk 2>/dev/null
                mkdir -p /tmp/extract_apk
                
                # APK 文件格式: [签名] + [控制数据] + [数据块]
                # 查找所有 gzip 压缩的 tar 块
                APK_SIZE=\$(stat -c%s $APK_FILE 2>/dev/null || stat -f%z $APK_FILE 2>/dev/null)
                echo \"APK 文件大小: \$APK_SIZE 字节\"
                
                # 尝试从不同位置查找并解压数据块
                for offset in 0 512 1024 1536 2048 2560 3072 4096 5120 6144 7168 8192; do
                    if [ \$offset -ge \$APK_SIZE ]; then
                        break
                    fi
                    echo \"尝试偏移量: \$offset\"
                    if dd if=$APK_FILE bs=1 skip=\$offset 2>/dev/null | gunzip -t 2>/dev/null; then
                        echo \"找到 gzip 流，偏移量: \$offset\"
                        dd if=$APK_FILE bs=1 skip=\$offset 2>/dev/null | gunzip 2>/dev/null | tar -xf - -C /tmp/extract_apk 2>/dev/null
                        if [ \$? -eq 0 ]; then
                            echo \"✓ 成功解压数据块\"
                        fi
                    fi
                done
                
                # 查找库文件
                LIBSSL=\$(find /tmp/extract_apk -name 'libssl.so.1.1' -type f 2>/dev/null | head -1)
                LIBCRYPTO=\$(find /tmp/extract_apk -name 'libcrypto.so.1.1' -type f 2>/dev/null | head -1)
                
                if [ -z \"\$LIBSSL\" ]; then
                    LIBSSL=\$(find /tmp/extract_apk -name 'libssl.so*' -type f 2>/dev/null | head -1)
                fi
                if [ -z \"\$LIBCRYPTO\" ]; then
                    LIBCRYPTO=\$(find /tmp/extract_apk -name 'libcrypto.so*' -type f 2>/dev/null | head -1)
                fi
                
                if [ -n \"\$LIBSSL\" ] && [ -f \"\$LIBSSL\" ]; then
                    mkdir -p /usr/lib
                    cp -f \"\$LIBSSL\" /usr/lib/libssl.so.1.1
                    [ -n \"\$LIBCRYPTO\" ] && cp -f \"\$LIBCRYPTO\" /usr/lib/libcrypto.so.1.1
                    chmod 755 /usr/lib/libssl.so.1.1 2>/dev/null
                    chmod 755 /usr/lib/libcrypto.so.1.1 2>/dev/null
                    echo \"✓ 库文件已复制: \$LIBSSL\"
                    exit 0
                else
                    echo '✗ 未找到库文件'
                    echo '所有解压的文件:'
                    find /tmp/extract_apk -type f 2>/dev/null
                    echo ''
                    echo '所有目录:'
                    find /tmp/extract_apk -type d 2>/dev/null
                    exit 1
                fi
            " 2>&1 | grep -v "^$"
        fi
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ 所有方法都失败了${NC}"
            echo ""
            echo "请手动执行以下命令查看详情:"
            echo "  docker exec portal-frontend sh -c 'cd /tmp && ls -la'"
            echo "  docker exec portal-frontend sh -c 'apk --version'"
            exit 1
        else
            echo -e "${GREEN}✓ 安装成功 (方法3: 直接解压)${NC}"
        fi
    fi
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 安装失败${NC}"
    echo ""
    echo "故障排查:"
    echo "1. 检查安装包完整性: ls -lh openssl1.1-compat.apk"
    echo "2. 检查容器版本: docker exec portal-frontend cat /etc/alpine-release"
    echo "3. 查看容器内文件: docker exec portal-frontend ls -la /tmp/"
    echo "4. 手动测试: docker exec portal-frontend sh -c 'cd /tmp && file openssl1.1-compat.apk'"
    exit 1
else
    echo -e "${GREEN}✓ 安装成功 (直接解压方式)${NC}"
fi

# 清理临时文件
docker exec -u 0 portal-frontend sh -c "rm -rf /tmp/$APK_FILE /tmp/usr /tmp/lib /tmp/.PKGINFO /tmp/.SIGN* 2>/dev/null" 2>/dev/null

# 验证库文件
echo -e "${YELLOW}[3/4] 验证库文件...${NC}"
docker exec portal-frontend ls -lh /usr/lib/libssl.so.1.1 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ libssl.so.1.1 已安装${NC}"
else
    echo -e "${RED}✗ libssl.so.1.1 未找到${NC}"
    exit 1
fi

# 重启容器
echo -e "${YELLOW}[4/4] 重启容器...${NC}"
docker restart portal-frontend
echo "等待容器启动 (5秒)..."
sleep 5

# 验证健康检查
echo ""
echo -e "${YELLOW}验证服务状态...${NC}"
if docker ps --format '{{.Names}}' | grep -q "geely-gateway"; then
    HEALTH_CODE=$(docker exec geely-gateway curl -s -o /dev/null -w "%{http_code}" http://portal-frontend:3000/api/health 2>/dev/null)
    if [ "$HEALTH_CODE" == "200" ]; then
        echo -e "${GREEN}✓ 健康检查: 200 OK${NC}"
    else
        echo -e "${YELLOW}⚠ 健康检查: $HEALTH_CODE (可能需要更多启动时间)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ geely-gateway 未运行，跳过健康检查${NC}"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  修复完成!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "请访问以下地址验证:"
echo "  http://<服务器IP>/api/health"
echo ""
