#!/bin/bash
set -e

# ============================================
# 通用阿里云镜像仓库推送脚本模板
# 使用方法：复制此脚本并修改配置部分
# ============================================

# ========== 配置区域 - 请根据项目修改 ==========

# 项目配置
PROJECT_NAME="your-project"  # 项目名称
PROJECT_DIR="/path/to/your/project"  # 项目根目录

# 阿里云配置
ALIYUN_REGISTRY="registry.cn-hangzhou.aliyuncs.com"  # 镜像仓库地址
ALIYUN_NAMESPACE="your-namespace"  # 命名空间（必须修改）
ALIYUN_USERNAME=""  # 用户名（留空则运行时输入）

# 镜像配置（根据项目调整）
SERVICES=(
    "backend:/path/to/backend"
    "frontend:/path/to/frontend"
    # 添加更多服务: "service-name:dockerfile-path"
)

# Docker Compose 文件路径（如果有）
DOCKER_COMPOSE_FILE="$PROJECT_DIR/docker/docker-compose.yml"
NGINX_CONF_FILE="$PROJECT_DIR/docker/nginx.conf"  # 可选

# ========== 以下代码一般不需要修改 ==========

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo "=========================================="
echo "$PROJECT_NAME - 阿里云镜像推送"
echo "镜像仓库: $ALIYUN_REGISTRY"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# ============================================
# 步骤 1: 检查配置
# ============================================
log_step "步骤 1: 检查配置..."

if [[ "$ALIYUN_NAMESPACE" == "your-namespace" ]]; then
    log_error "请先配置 ALIYUN_NAMESPACE"
    exit 1
fi

if [[ "$PROJECT_NAME" == "your-project" ]]; then
    log_error "请先配置 PROJECT_NAME"
    exit 1
fi

if [[ -z "$ALIYUN_USERNAME" ]]; then
    echo -n "请输入阿里云用户名: "
    read ALIYUN_USERNAME
fi

# 镜像标签
IMAGE_TAG=$(date +%Y%m%d-%H%M%S)
log_info "镜像标签: $IMAGE_TAG"
echo ""

# ============================================
# 步骤 2: 清理本地旧镜像
# ============================================
log_step "步骤 2: 清理本地旧镜像..."

for service_config in "${SERVICES[@]}"; do
    service_name="${service_config%%:*}"
    docker rmi $PROJECT_NAME-$service_name:latest 2>/dev/null || true
done
docker image prune -f > /dev/null 2>&1 || true

log_info "清理完成"
echo ""

# ============================================
# 步骤 3: 构建镜像
# ============================================
log_step "步骤 3: 构建生产版本镜像..."

ARCH=$(uname -m)
log_info "当前架构: $ARCH"

# 配置 buildx（如果是 ARM64）
if [[ "$ARCH" == "arm64" ]]; then
    log_info "配置 Docker Buildx..."
    docker buildx create --use --name multiarch-builder 2>/dev/null || \
        docker buildx use multiarch-builder
    docker buildx inspect --bootstrap > /dev/null 2>&1 || true
fi

# 构建所有服务
for service_config in "${SERVICES[@]}"; do
    service_name="${service_config%%:*}"
    build_path="${service_config##*:}"
    
    log_info "构建 $service_name 镜像..."
    
    IMAGE_LOCAL="$PROJECT_NAME-$service_name"
    IMAGE_REMOTE="$ALIYUN_REGISTRY/$ALIYUN_NAMESPACE/$PROJECT_NAME-$service_name"
    
    cd "$build_path"
    
    if [[ "$ARCH" == "arm64" ]]; then
        docker buildx build \
            --platform linux/amd64 \
            -t $IMAGE_LOCAL:latest \
            -t $IMAGE_LOCAL:$IMAGE_TAG \
            -t $IMAGE_REMOTE:$IMAGE_TAG \
            -t $IMAGE_REMOTE:latest \
            --load \
            .
    else
        docker build \
            --platform linux/amd64 \
            -t $IMAGE_LOCAL:latest \
            -t $IMAGE_LOCAL:$IMAGE_TAG \
            -t $IMAGE_REMOTE:$IMAGE_TAG \
            -t $IMAGE_REMOTE:latest \
            .
    fi
    
    if [[ $? -eq 0 ]]; then
        log_info "$service_name 镜像构建成功"
    else
        log_error "$service_name 镜像构建失败"
        exit 1
    fi
done

echo ""

# ============================================
# 步骤 4: 登录阿里云
# ============================================
log_step "步骤 4: 登录阿里云镜像仓库..."

if docker login --username=$ALIYUN_USERNAME $ALIYUN_REGISTRY; then
    log_info "登录成功"
else
    log_error "登录失败"
    exit 1
fi

echo ""

# ============================================
# 步骤 5: 推送镜像
# ============================================
log_step "步骤 5: 推送镜像到阿里云..."

for service_config in "${SERVICES[@]}"; do
    service_name="${service_config%%:*}"
    IMAGE_REMOTE="$ALIYUN_REGISTRY/$ALIYUN_NAMESPACE/$PROJECT_NAME-$service_name"
    
    log_info "推送 $service_name 镜像..."
    docker push $IMAGE_REMOTE:$IMAGE_TAG
    docker push $IMAGE_REMOTE:latest
    
    if [[ $? -eq 0 ]]; then
        log_info "$service_name 镜像推送成功"
    else
        log_error "$service_name 镜像推送失败"
        exit 1
    fi
done

echo ""

# ============================================
# 步骤 6: 生成部署配置
# ============================================
log_step "步骤 6: 生成部署配置..."

DEPLOY_TEMP_DIR="$PROJECT_DIR/deploy-temp"
mkdir -p "$DEPLOY_TEMP_DIR"

# 如果有 docker-compose.yml，生成新版本
if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
    log_info "生成 docker-compose.yml..."
    
    # 读取原始文件并替换镜像地址
    cp "$DOCKER_COMPOSE_FILE" "$DEPLOY_TEMP_DIR/docker-compose.yml"
    
    for service_config in "${SERVICES[@]}"; do
        service_name="${service_config%%:*}"
        IMAGE_REMOTE="$ALIYUN_REGISTRY/$ALIYUN_NAMESPACE/$PROJECT_NAME-$service_name"
        
        # 替换镜像地址（使用 sed）
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s|image: $PROJECT_NAME-$service_name:latest|image: $IMAGE_REMOTE:$IMAGE_TAG|g" \
                "$DEPLOY_TEMP_DIR/docker-compose.yml"
        else
            # Linux
            sed -i "s|image: $PROJECT_NAME-$service_name:latest|image: $IMAGE_REMOTE:$IMAGE_TAG|g" \
                "$DEPLOY_TEMP_DIR/docker-compose.yml"
        fi
    done
    
    log_info "docker-compose.yml 已生成"
fi

# 复制其他配置文件
if [[ -f "$NGINX_CONF_FILE" ]]; then
    cp "$NGINX_CONF_FILE" "$DEPLOY_TEMP_DIR/"
    log_info "nginx.conf 已复制"
fi

log_info "部署配置已生成到: $DEPLOY_TEMP_DIR"
echo ""

# ============================================
# 完成
# ============================================
echo "=========================================="
log_info "镜像推送完成！"
echo "=========================================="
echo ""
echo "镜像信息："
for service_config in "${SERVICES[@]}"; do
    service_name="${service_config%%:*}"
    IMAGE_REMOTE="$ALIYUN_REGISTRY/$ALIYUN_NAMESPACE/$PROJECT_NAME-$service_name"
    echo "  $service_name: $IMAGE_REMOTE:$IMAGE_TAG"
done
echo ""
echo "下一步："
echo "  1. 使用部署脚本自动部署"
echo "  2. 或手动在服务器上执行："
echo "     cd /path/to/deploy"
echo "     docker login $ALIYUN_REGISTRY"
echo "     docker compose pull"
echo "     docker compose up -d"
echo ""
