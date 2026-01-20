#!/bin/bash
set -e

# ============================================
# Todify4 离线部署构建脚本 (修复版 v13)
# 参考: 堡垒机 Docker 部署主指南
# ============================================

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
YELLOW='\033[1;33m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 确保在脚本所在目录执行
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 检查项目根目录
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
if [ ! -d "$PROJECT_ROOT/backend" ]; then
    log_info "错误: 无法找到 backend 目录。当前路径: $(pwd)"
    log_info "预期项目根目录: $PROJECT_ROOT"
    exit 1
fi

# 清理 macOS 元数据文件 (解决 xattr error)
log_info "清理项目目录中的 macOS 元数据文件..."
find "$PROJECT_ROOT" -name "._*" -delete || true

# ============================================
# 镜像源选择逻辑
# ============================================
DAOCLOUD_NODE="m.daocloud.io/docker.io/library/node:20-alpine"
DAOCLOUD_NGINX="m.daocloud.io/docker.io/library/nginx:alpine"
OFFICIAL_NODE="node:20-alpine"
OFFICIAL_NGINX="nginx:alpine"

# 测试网络连接
check_mirror() {
    log_info "正在测试镜像源连接..."
    if curl --connect-timeout 5 -sI "https://m.daocloud.io" >/dev/null; then
        return 0
    else
        return 1
    fi
}

if check_mirror; then
    log_info "使用 DaoCloud 加速源"
    NODE_IMAGE="$DAOCLOUD_NODE"
    NGINX_IMAGE="$DAOCLOUD_NGINX"
else
    log_warn "DaoCloud 连接失败或超时，切换回官方源 (可能会慢)..."
    NODE_IMAGE="$OFFICIAL_NODE"
    NGINX_IMAGE="$OFFICIAL_NGINX"
fi

log_info "最终使用镜像:"
log_info "  Node:  $NODE_IMAGE"
log_info "  Nginx: $NGINX_IMAGE"

# 0. 清理旧镜像
log_step "0. 清理旧镜像..."
log_info "尝试删除旧的 todify4 镜像以避免 digest 不匹配..."
docker rmi todify4-backend:latest todify4-frontend:latest 2>/dev/null || true
docker builder prune -f >/dev/null 2>&1 || true

# ---------------------------------------------------------
# 全局设置：使用系统临时目录
# ---------------------------------------------------------
TEMP_DIR=$(mktemp -d)
# 确保脚本退出时清理临时目录
trap 'rm -rf "$TEMP_DIR"' EXIT

# 1. 构建镜像
log_step "1. 构建镜像 (linux/amd64)..."

log_info "构建 todify4-backend..."

# 尝试拉取基础镜像，失败则重试
log_info "预拉取基础镜像..."
if ! docker pull --platform linux/amd64 "$NODE_IMAGE"; then
    log_warn "拉取 $NODE_IMAGE 失败，尝试使用官方源重试..."
    NODE_IMAGE="$OFFICIAL_NODE"
    docker pull --platform linux/amd64 "$NODE_IMAGE"
fi

# ---------------------------------------------------------
# 后端 Dockerfile 生成 (注入阿里云 Alpine 源 & NPM 镜像)
# ---------------------------------------------------------
log_info "生成临时后端 Dockerfile..."
TEMP_BACKEND_DOCKERFILE="$TEMP_DIR/Dockerfile.backend"

cat > "$TEMP_BACKEND_DOCKERFILE" <<EOF
ARG BASE_IMAGE=$NODE_IMAGE
FROM \${BASE_IMAGE} AS builder

# [修复] 替换 Alpine 软件源为阿里云
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装构建依赖（sqlite3 原生模块需要）
RUN apk add --no-cache python3 make g++ sqlite

# 设置工作目录
WORKDIR /app

# 复制 package 文件
COPY package*.json ./
COPY tsconfig.json ./

# [修复] 设置 NPM 镜像以及 sqlite3/node-gyp 镜像 (通过 .npmrc)
RUN echo "registry=https://registry.npmmirror.com" > .npmrc && \
    echo "sqlite3_binary_host_mirror=https://npmmirror.com/mirrors/sqlite3" >> .npmrc && \
    echo "disturl=https://npmmirror.com/mirrors/node" >> .npmrc

# 安装依赖
RUN npm ci --production=false

# 复制源代码
COPY src ./src

# 构建项目
RUN npm run build

# 生产环境镜像
FROM \${BASE_IMAGE}

# [修复] 替换 Alpine 软件源为阿里云 (运行时阶段)
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装必要的系统依赖（SQLite运行时需要，以及健康检查工具）
RUN apk add --no-cache sqlite-libs wget bash gettext

# 设置工作目录
WORKDIR /app

# 从构建阶段复制文件
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/tsconfig.json ./

# 复制数据库初始化脚本
COPY scripts/init-database.sh /app/scripts/init-database.sh
COPY docker-entrypoint.sh /app/docker-entrypoint.sh

# 创建 SQL 脚本目录并从构建阶段复制 SQL 文件
RUN mkdir -p /app/src/scripts
COPY --from=builder /app/src/scripts/unified-database-schema-v2.sql /app/src/scripts/
COPY --from=builder /app/src/scripts/unified-database-indexes-v2.sql /app/src/scripts/

# 创建必要的目录
RUN mkdir -p /app/data /app/init-data && \
    chmod +x /app/scripts/init-database.sh /app/docker-entrypoint.sh

# 设置环境变量
ENV NODE_ENV=production
ENV PORT=8113

# 暴露端口
EXPOSE 8113

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8113/api/health || exit 1

# 使用入口脚本启动应用
ENTRYPOINT ["/app/docker-entrypoint.sh"]
EOF

log_info "使用 buildx 构建并导出后端镜像..."
# 使用 -f 指向临时 Dockerfile 以规避外接磁盘的 xattr 权限问题
docker buildx build --platform linux/amd64 \
  -f "$TEMP_BACKEND_DOCKERFILE" \
  -t todify4-backend:latest \
  --output type=docker,dest=./todify4-backend.tar \
  "$PROJECT_ROOT/backend"

log_info "构建 todify4-frontend..."
# 预拉取 Nginx
if ! docker pull --platform linux/amd64 "$NGINX_IMAGE"; then
    log_warn "拉取 $NGINX_IMAGE 失败，尝试使用官方源重试..."
    NGINX_IMAGE="$OFFICIAL_NGINX"
    docker pull --platform linux/amd64 "$NGINX_IMAGE"
fi

# ---------------------------------------------------------
# 前端 Dockerfile 生成 (注入阿里云 Alpine 源 & NPM 镜像)
# ---------------------------------------------------------
log_info "生成临时前端 Dockerfile..."
TEMP_FRONTEND_DOCKERFILE="$TEMP_DIR/Dockerfile.frontend"

cat > "$TEMP_FRONTEND_DOCKERFILE" <<EOF
ARG NODE_IMAGE=$NODE_IMAGE
ARG NGINX_IMAGE=$NGINX_IMAGE

FROM \${NODE_IMAGE} AS builder

# [修复] 替换 Alpine 软件源为阿里云
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

WORKDIR /app

# 复制 package 文件
COPY package*.json ./

# [修复] 设置 NPM 镜像
RUN npm config set registry https://registry.npmmirror.com

# 安装依赖
RUN npm ci

# 复制源代码
COPY . .

# 构建生产版本
RUN npm run build

# 生产环境镜像（使用 nginx 服务静态文件）
FROM \${NGINX_IMAGE}

# [修复] 替换 Alpine 软件源为阿里云
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 复制构建产物到 nginx
COPY --from=builder /app/dist /usr/share/nginx/html

# 复制 nginx 配置文件
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露端口
EXPOSE 80

# 启动 nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

log_info "使用 buildx 构建并导出前端镜像..."
# 使用 -f 指向临时 Dockerfile 以规避外接磁盘的 xattr 权限问题
docker buildx build --platform linux/amd64 \
  -f "$TEMP_FRONTEND_DOCKERFILE" \
  -t todify4-frontend:latest \
  --output type=docker,dest=./todify4-frontend.tar \
  "$PROJECT_ROOT/frontend"

# 2. 拉取依赖镜像
log_step "2. 拉取依赖镜像..."
log_info "准备 nginx:alpine..."

# 显式拉取并保存 Nginx 镜像
# 使用 buildx output=type=docker 避免 save 时的 content digest not found 错误
docker buildx build --platform linux/amd64 \
  -t nginx:alpine \
  --output type=docker,dest=./nginx.tar \
  - <<EOF
FROM $NGINX_IMAGE
EOF

# 3. 打包镜像包
log_step "3. 打包镜像包 (todify4-all.tar)..."

log_info "正在合并 tar 包..."
if command -v tar >/dev/null; then
    if [[ -f todify4-backend.tar && -f todify4-frontend.tar && -f nginx.tar ]]; then
        tar -cvf todify4-all.tar todify4-backend.tar todify4-frontend.tar nginx.tar
        rm todify4-backend.tar todify4-frontend.tar nginx.tar
        log_info "镜像包打包成功: todify4-all.tar"
    else
        log_warn "警告: 部分镜像文件缺失:"
        [[ ! -f todify4-backend.tar ]] && echo "  - todify4-backend.tar 缺失"
        [[ ! -f todify4-frontend.tar ]] && echo "  - todify4-frontend.tar 缺失"
        [[ ! -f nginx.tar ]] && echo "  - nginx.tar 缺失"
    fi
else
    log_warn "警告: tar 命令不可用，无法合并。请分别传输以下文件:"
    ls -lh *.tar
fi

log_info "请将以下文件传输到服务器:"
log_info "  - todify4-all.tar (或独立的 .tar 文件)"
log_info "  - docker-compose.prod.yml (重命名为 docker-compose.yml)"
log_info "  - nginx.conf"
log_info "并按照 DEPLOY_README.md 进行部署。"
