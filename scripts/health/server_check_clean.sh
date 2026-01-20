#!/bin/bash

# 阿里云服务器状态检查和清理脚本
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVER_HOST="${SERVER_HOST:-}"
SERVER_USER="${SERVER_USER:-root}"
SSH_KEY="${SSH_KEY:-}"
PORT="${PORT:-22}"

show_usage() {
    echo -e "${BLUE}使用方法:${NC}"
    echo "  $0 [选项] <服务器地址>"
    echo ""
    echo -e "${BLUE}选项:${NC}"
    echo "  -u, --user USER       SSH用户名 (默认: root)"
    echo "  -p, --port PORT       SSH端口 (默认: 22)"
    echo "  -k, --key KEY_PATH    SSH私钥路径"
    echo "  -h, --help           显示帮助"
    echo ""
    echo -e "${BLUE}示例:${NC}"
    echo "  $0 192.168.1.100"
    echo "  $0 -u ubuntu -k ~/.ssh/id_rsa 192.168.1.100"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                SERVER_USER="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -k|--key)
                SSH_KEY="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_usage
                exit 1
                ;;
            *)
                SERVER_HOST="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$SERVER_HOST" ]]; then
        echo -e "${RED}错误: 请提供服务器地址${NC}"
        show_usage
        exit 1
    fi
}

remote_exec() {
    local cmd="$1"
    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    
    if [[ -n "$SSH_KEY" ]]; then
        ssh_opts="$ssh_opts -i $SSH_KEY"
    fi
    
    ssh $ssh_opts -p $PORT $SERVER_USER@$SERVER_HOST "$cmd"
}

print_separator() {
    echo -e "\n${BLUE}=======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

check_connection() {
    print_separator "检查SSH连接"
    echo -e "${YELLOW}连接到 $SERVER_USER@$SERVER_HOST:$PORT...${NC}"
    
    if remote_exec "echo '连接成功'" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ SSH连接成功${NC}"
    else
        echo -e "${RED}✗ SSH连接失败${NC}"
        exit 1
    fi
}

check_system_info() {
    print_separator "系统信息"
    remote_exec "echo '系统版本:' && cat /etc/os-release | grep PRETTY_NAME"
    remote_exec "echo -e '\n运行时间:' && uptime"
    remote_exec "echo -e '\n内核版本:' && uname -r"
}

check_disk_usage() {
    print_separator "磁盘使用情况"
    remote_exec "df -h"
    
    echo -e "\n${YELLOW}根目录各目录大小 (TOP 10):${NC}"
    remote_exec "du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10"
}

check_memory() {
    print_separator "内存使用情况"
    remote_exec "free -h"
    
    echo -e "\n${YELLOW}内存占用TOP 10进程:${NC}"
    remote_exec "ps aux --sort=-%mem | head -11"
}

find_large_files() {
    print_separator "查找大文件 (>100MB)"
    remote_exec "find / -type f -size +100M 2>/dev/null | head -20 | xargs -I {} du -h {} 2>/dev/null | sort -hr"
}

check_logs() {
    print_separator "日志文件检查"
    echo -e "${YELLOW}/var/log 目录大小:${NC}"
    remote_exec "du -sh /var/log 2>/dev/null"
    
    echo -e "\n${YELLOW}大日志文件 (>10MB):${NC}"
    remote_exec "find /var/log -type f -size +10M 2>/dev/null | xargs -I {} du -h {} 2>/dev/null | sort -hr"
}

check_docker() {
    print_separator "Docker 状态检查"
    
    if remote_exec "command -v docker > /dev/null 2>&1" > /dev/null 2>&1; then
        echo -e "${YELLOW}Docker 容器:${NC}"
        remote_exec "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Size}}' 2>/dev/null || echo 'Docker服务未运行'"
        
        echo -e "\n${YELLOW}Docker 镜像:${NC}"
        remote_exec "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' 2>/dev/null | head -15"
        
        echo -e "\n${YELLOW}Docker 空间使用:${NC}"
        remote_exec "docker system df 2>/dev/null || echo 'Docker服务未运行'"
    else
        echo -e "${YELLOW}Docker 未安装${NC}"
    fi
}

show_cleanup_suggestions() {
    print_separator "清理建议"
    
    echo -e "${GREEN}可执行的清理操作：${NC}"
    echo ""
    echo "1. 清理包管理器缓存："
    echo "   apt-get clean && apt-get autoclean  # Debian/Ubuntu"
    echo "   yum clean all  # CentOS/RHEL"
    echo ""
    echo "2. 清理日志："
    echo "   journalctl --vacuum-time=7d  # 清理7天前的日志"
    echo "   find /var/log -type f -name '*.log' -mtime +30 -delete  # 删除30天前的日志"
    echo ""
    echo "3. 清理临时文件："
    echo "   rm -rf /tmp/*"
    echo "   rm -rf /var/tmp/*"
    echo ""
    echo "4. Docker 清理："
    echo "   docker system prune -a --volumes -f  # 清理所有未使用的资源"
    echo ""
    echo "5. 清理旧内核（Ubuntu/Debian）："
    echo "   apt-get autoremove --purge"
    echo ""
}

prompt_cleanup() {
    print_separator "自动清理"
    
    echo -e "${YELLOW}是否执行自动清理？(y/n)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        execute_cleanup
    else
        echo -e "${BLUE}跳过自动清理${NC}"
    fi
}

execute_cleanup() {
    echo -e "${GREEN}开始执行清理操作...${NC}\n"
    
    # 1. 清理包缓存
    echo -e "${YELLOW}1. 清理包缓存...${NC}"
    if remote_exec "command -v apt-get > /dev/null 2>&1"; then
        remote_exec "apt-get clean && apt-get autoclean -y" 2>/dev/null || echo "清理失败或无权限"
    elif remote_exec "command -v yum > /dev/null 2>&1"; then
        remote_exec "yum clean all" 2>/dev/null || echo "清理失败或无权限"
    fi
    
    # 2. 清理旧日志
    echo -e "\n${YELLOW}2. 清理旧日志文件...${NC}"
    remote_exec "journalctl --vacuum-time=7d 2>/dev/null || echo '无journalctl或无权限'"
    remote_exec "find /var/log -type f -name '*.log' -mtime +30 -size +10M 2>/dev/null | wc -l | xargs -I {} echo '找到 {} 个旧日志文件'"
    
    # 3. 清理临时文件
    echo -e "\n${YELLOW}3. 清理临时文件...${NC}"
    remote_exec "find /tmp -type f -mtime +7 -delete 2>/dev/null && echo '已清理/tmp' || echo '无权限清理/tmp'"
    
    # 4. Docker清理
    echo -e "\n${YELLOW}4. 清理Docker资源...${NC}"
    if remote_exec "command -v docker > /dev/null 2>&1" > /dev/null 2>&1; then
        remote_exec "docker system prune -f 2>/dev/null || echo 'Docker清理失败或服务未运行'"
    else
        echo "Docker未安装，跳过"
    fi
    
    # 5. 清理旧内核和包
    echo -e "\n${YELLOW}5. 清理旧包...${NC}"
    if remote_exec "command -v apt-get > /dev/null 2>&1"; then
        remote_exec "apt-get autoremove -y 2>/dev/null || echo '清理失败或无权限'"
    fi
    
    echo -e "\n${GREEN}清理完成！${NC}"
    
    # 显示清理后的状态
    print_separator "清理后磁盘使用情况"
    remote_exec "df -h"
}

main() {
    parse_args "$@"
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  阿里云服务器检查和清理工具${NC}"
    echo -e "${GREEN}  服务器: $SERVER_USER@$SERVER_HOST:$PORT${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    check_connection
    check_system_info
    check_disk_usage
    check_memory
    find_large_files
    check_logs
    check_docker
    show_cleanup_suggestions
    prompt_cleanup
    
    echo -e "\n${GREEN}检查完成！${NC}"
}

main "$@"
