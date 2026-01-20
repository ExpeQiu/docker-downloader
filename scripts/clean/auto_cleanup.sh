#!/bin/bash

# 阿里云服务器自动清理脚本
# 用途：定期清理 Docker 资源、日志、缓存等，释放磁盘空间
# 执行频率：建议每周执行一次

set -e

# 日志配置
LOG_DIR="/var/log/auto-cleanup"
LOG_FILE="$LOG_DIR/cleanup-$(date +%Y%m%d-%H%M%S).log"
DISK_THRESHOLD=80  # 磁盘使用率阈值（超过此值才执行清理）

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 日志函数
log() {
    local message="$1"
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

log_info() {
    log "${BLUE}ℹ $1${NC}"
}

log_warning() {
    log "${YELLOW}⚠ $1${NC}"
}

log_error() {
    log "${RED}✗ $1${NC}"
}

# 获取磁盘使用率
get_disk_usage() {
    df / | tail -1 | awk '{print $5}' | sed 's/%//'
}

# 获取磁盘信息
get_disk_info() {
    df -h / | tail -1
}

# 检查是否需要清理
check_cleanup_needed() {
    local usage=$(get_disk_usage)
    log_info "当前磁盘使用率: ${usage}%"
    
    if [ "$usage" -gt "$DISK_THRESHOLD" ]; then
        log_warning "磁盘使用率超过 ${DISK_THRESHOLD}%，开始清理"
        return 0
    else
        log_info "磁盘使用率正常，跳过清理（阈值: ${DISK_THRESHOLD}%）"
        return 1
    fi
}

# 记录清理前状态
record_before_state() {
    log_info "=== 清理前状态 ==="
    get_disk_info | tee -a "$LOG_FILE"
    
    log_info "Docker 镜像数量: $(docker images -q 2>/dev/null | wc -l)"
    log_info "Docker 容器数量: $(docker ps -a -q 2>/dev/null | wc -l)"
    log_info "日志目录大小: $(du -sh /var/log 2>/dev/null | awk '{print $1}')"
}

# 1. 清理停止的容器
cleanup_stopped_containers() {
    log_info "--- 1. 清理停止的容器 ---"
    
    local stopped_count=$(docker ps -a -f status=exited -q 2>/dev/null | wc -l)
    
    if [ "$stopped_count" -gt 0 ]; then
        docker container prune -f 2>&1 | tee -a "$LOG_FILE"
        log_success "清理了 ${stopped_count} 个停止的容器"
    else
        log_info "没有停止的容器需要清理"
    fi
}

# 2. 清理悬空镜像
cleanup_dangling_images() {
    log_info "--- 2. 清理悬空镜像 ---"
    
    local dangling_count=$(docker images -f dangling=true -q 2>/dev/null | wc -l)
    
    if [ "$dangling_count" -gt 0 ]; then
        docker image prune -f 2>&1 | tee -a "$LOG_FILE"
        log_success "清理了 ${dangling_count} 个悬空镜像"
    else
        log_info "没有悬空镜像需要清理"
    fi
}

# 3. 清理未使用的卷
cleanup_unused_volumes() {
    log_info "--- 3. 清理未使用的卷 ---"
    
    docker volume prune -f 2>&1 | tee -a "$LOG_FILE"
    log_success "清理完成"
}

# 4. 清理 Docker 构建缓存
cleanup_build_cache() {
    log_info "--- 4. 清理 Docker 构建缓存 ---"
    
    # 只清理未使用的构建缓存，保留最近使用的
    docker builder prune -f 2>&1 | tee -a "$LOG_FILE"
    log_success "构建缓存清理完成"
}

# 5. 清理包管理器缓存
cleanup_package_cache() {
    log_info "--- 5. 清理包管理器缓存 ---"
    
    if command -v dnf &> /dev/null; then
        dnf clean all 2>&1 | tee -a "$LOG_FILE"
        log_success "DNF 缓存清理完成"
    elif command -v yum &> /dev/null; then
        yum clean all 2>&1 | tee -a "$LOG_FILE"
        log_success "YUM 缓存清理完成"
    elif command -v apt-get &> /dev/null; then
        apt-get clean 2>&1 | tee -a "$LOG_FILE"
        apt-get autoclean 2>&1 | tee -a "$LOG_FILE"
        log_success "APT 缓存清理完成"
    else
        log_info "未检测到包管理器"
    fi
}

# 6. 清理系统日志（保留最近7天）
cleanup_system_logs() {
    log_info "--- 6. 清理系统日志（保留7天） ---"
    
    if command -v journalctl &> /dev/null; then
        journalctl --vacuum-time=7d 2>&1 | tee -a "$LOG_FILE"
        log_success "系统日志清理完成"
    else
        log_info "journalctl 不可用"
    fi
}

# 7. 清理应用日志（仅清理大于100MB且超过30天的日志）
cleanup_old_logs() {
    log_info "--- 7. 清理旧应用日志 ---"
    
    local log_count=$(find /var/log -type f -name "*.log" -mtime +30 -size +100M 2>/dev/null | wc -l)
    
    if [ "$log_count" -gt 0 ]; then
        find /var/log -type f -name "*.log" -mtime +30 -size +100M 2>/dev/null -exec truncate -s 0 {} \;
        log_success "清理了 ${log_count} 个旧日志文件"
    else
        log_info "没有需要清理的旧日志文件"
    fi
}

# 8. 清理临时文件（7天前）
cleanup_temp_files() {
    log_info "--- 8. 清理临时文件 ---"
    
    local temp_count=$(find /tmp -type f -mtime +7 2>/dev/null | wc -l)
    
    if [ "$temp_count" -gt 0 ]; then
        find /tmp -type f -mtime +7 -delete 2>/dev/null
        log_success "清理了 ${temp_count} 个临时文件"
    else
        log_info "没有旧临时文件需要清理"
    fi
}

# 9. 清理旧的清理日志（保留最近10次）
cleanup_old_cleanup_logs() {
    log_info "--- 9. 清理旧的清理日志 ---"
    
    if [ -d "$LOG_DIR" ]; then
        local log_files=$(ls -t "$LOG_DIR"/cleanup-*.log 2>/dev/null | tail -n +11)
        if [ -n "$log_files" ]; then
            echo "$log_files" | xargs rm -f
            log_success "清理了旧的清理日志"
        else
            log_info "清理日志数量正常"
        fi
    fi
}

# 记录清理后状态
record_after_state() {
    log_info "=== 清理后状态 ==="
    get_disk_info | tee -a "$LOG_FILE"
    
    log_info "Docker 镜像数量: $(docker images -q 2>/dev/null | wc -l)"
    log_info "Docker 容器数量: $(docker ps -a -q 2>/dev/null | wc -l)"
    log_info "日志目录大小: $(du -sh /var/log 2>/dev/null | awk '{print $1}')"
}

# 计算释放的空间
calculate_freed_space() {
    local before_used=$1
    local after_used=$2
    local freed=$((before_used - after_used))
    
    if [ "$freed" -gt 0 ]; then
        log_success "释放磁盘空间: ${freed}G"
    else
        log_info "磁盘空间变化: ${freed}G"
    fi
}

# 发送通知（可选，需要配置）
send_notification() {
    local message="$1"
    # TODO: 这里可以添加钉钉、企业微信等通知
    # 例如：curl -X POST -H 'Content-Type: application/json' -d "{\"text\": \"$message\"}" $WEBHOOK_URL
    log_info "通知: $message"
}

# 主函数
main() {
    log_info "========================================="
    log_info "  阿里云服务器自动清理脚本"
    log_info "  执行时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "========================================="
    
    # 检查是否需要清理
    if ! check_cleanup_needed; then
        log_info "清理完成（未达到清理阈值）"
        exit 0
    fi
    
    # 记录清理前状态
    local before_disk_used=$(get_disk_usage)
    record_before_state
    
    # 执行清理
    log_info ""
    log_info "开始执行清理任务..."
    log_info ""
    
    cleanup_stopped_containers
    cleanup_dangling_images
    cleanup_unused_volumes
    cleanup_build_cache
    cleanup_package_cache
    cleanup_system_logs
    cleanup_old_logs
    cleanup_temp_files
    cleanup_old_cleanup_logs
    
    # 记录清理后状态
    log_info ""
    local after_disk_used=$(get_disk_usage)
    record_after_state
    
    # 计算释放空间
    log_info ""
    calculate_freed_space "$before_disk_used" "$after_disk_used"
    
    # 发送通知
    send_notification "服务器清理完成，磁盘使用率: ${before_disk_used}% -> ${after_disk_used}%"
    
    log_info ""
    log_success "========================================="
    log_success "  清理任务执行完成"
    log_success "  日志文件: $LOG_FILE"
    log_success "========================================="
}

# 执行主函数
main "$@"
