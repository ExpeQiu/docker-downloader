#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# =================================================================
# 辅助函数
# =================================================================

function fix_portal_openssl() {
    echo -e "${GREEN}正在修复 Unified Portal 500 错误 (OpenSSL 兼容性)...${NC}"
    if docker ps | grep -q portal-frontend; then
        echo "正在容器 portal-frontend 中安装 openssl1.1-compat..."
        docker exec -u 0 portal-frontend apk add --no-cache openssl1.1-compat
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}安装成功。正在重启容器...${NC}"
            docker restart portal-frontend
            echo "容器已重启。"
        else
            echo -e "${RED}安装失败。请检查容器日志。${NC}"
        fi
    else
        echo -e "${RED}错误: portal-frontend 容器未运行。${NC}"
    fi
}

function reload_nginx() {
    echo -e "${GREEN}正在重载 Nginx 配置...${NC}"
    if docker ps | grep -q geely-gateway; then
        docker exec geely-gateway nginx -s reload
        echo -e "${GREEN}Nginx 配置重载完成。${NC}"
    else
        echo -e "${RED}错误: geely-gateway 容器未运行。${NC}"
    fi
}

# =================================================================
# 命令行参数处理
# =================================================================
if [ "$1" == "fix_portal" ]; then
    fix_portal_openssl
    exit 0
fi

if [ "$1" == "reload_nginx" ]; then
    reload_nginx
    exit 0
fi

if [ "$1" == "help" ]; then
    echo "用法: ./deploy.sh [command]"
    echo "命令:"
    echo "  (无)          执行完整部署流程"
    echo "  fix_portal    仅修复 Unified Portal OpenSSL 问题"
    echo "  reload_nginx  仅重载 Nginx 配置"
    exit 0
fi

echo -e "${GREEN}=== Geely Unified Portal 一键部署脚本 ===${NC}"
echo "开始时间: $(date)"

# 1. 检查 Docker 环境
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: 未检测到 Docker，请先安装 Docker。${NC}"
    exit 1
fi

# 检查 Docker Compose (兼容 docker-compose 和 docker compose)
DOCKER_COMPOSE_CMD=""

# 优先检查当前目录是否有离线安装包
if [ -f "./docker-compose" ]; then
    echo "检测到离线 docker-compose 安装包，正在安装..."
    cp ./docker-compose /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "安装完成。"
fi

if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo -e "${RED}错误: 未检测到 Docker Compose 或 docker compose 插件，且未发现离线安装包。${NC}"
    echo "尝试在线安装 (如果失败，请手动下载 docker-compose-linux-x86_64 并重命名为 docker-compose 放到此目录):"
    echo "sudo curl -L \"https://get.daocloud.io/docker/compose/releases/download/v2.23.0/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
    echo "sudo chmod +x /usr/local/bin/docker-compose"
    exit 1
fi

echo -e "${GREEN}使用 Docker Compose 命令: $DOCKER_COMPOSE_CMD${NC}"

# 2. 创建数据目录 (可选，如果 docker-compose 使用 volume 自动管理则不需要)
echo "正在检查配置目录..."
mkdir -p ./nginx
mkdir -p ./envs

# 3. 加载镜像 (自动扫描当前目录下的 .tar 文件)
echo "正在扫描并加载 Docker 镜像..."
count=0
for tar_file in *.tar; do
    if [ -f "$tar_file" ]; then
        echo "正在加载: $tar_file ..."
        docker load -i "$tar_file"
        ((count++))
    fi
done

if [ $count -eq 0 ]; then
    echo -e "${RED}警告: 当前目录下未找到 .tar 镜像文件。请确保已上传镜像包。${NC}"
    read -p "是否继续尝试启动服务? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}成功加载 $count 个镜像文件。${NC}"
fi

# 4. 启动服务
echo "正在启动所有服务..."
$DOCKER_COMPOSE_CMD up -d

# 5. 检查状态
echo "等待服务启动 (10秒)..."
sleep 10
$DOCKER_COMPOSE_CMD ps

# 6. 执行数据库迁移 (Unified Portal)
echo "正在执行 Unified Portal 数据库迁移..."
if docker ps | grep -q portal-frontend; then
    # 修复 Prisma OpenSSL 1.1 兼容性问题
    echo "检查 OpenSSL 兼容性..."
    docker exec -u 0 portal-frontend apk add --no-cache openssl1.1-compat || echo "OpenSSL 兼容包安装失败或已存在"

    echo "执行 Prisma Migrate..."
    docker exec portal-frontend npx prisma migrate deploy
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Unified Portal 数据库迁移成功。${NC}"
    else
        echo -e "${RED}Unified Portal 数据库迁移失败。请检查日志。${NC}"
    fi
else
    echo -e "${RED}错误: portal-frontend 容器未运行，跳过数据库迁移。${NC}"
fi

echo -e "${GREEN}=== 部署完成 ===${NC}"
echo "请访问: http://<服务器IP> 验证服务"
echo "- 统一门户: http://<服务器IP>/"
echo "- TPD2: http://<服务器IP>/tpd2/"
echo "- Writer: http://<服务器IP>/writer/"
echo "- Todify4: http://<服务器IP>/todify/"
