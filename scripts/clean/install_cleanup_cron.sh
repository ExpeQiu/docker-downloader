#!/bin/bash

# 安装定期清理任务到 crontab
# 使用方法：./install_cleanup_cron.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_SCRIPT="$SCRIPT_DIR/auto_cleanup.sh"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  安装定期清理任务${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查清理脚本是否存在
if [ ! -f "$CLEANUP_SCRIPT" ]; then
    echo -e "${RED}错误: 清理脚本不存在: $CLEANUP_SCRIPT${NC}"
    exit 1
fi

# 确保脚本有执行权限
chmod +x "$CLEANUP_SCRIPT"

echo -e "${YELLOW}请选择执行频率:${NC}"
echo "1) 每天凌晨 3:00 执行"
echo "2) 每周日凌晨 3:00 执行"
echo "3) 每月1号凌晨 3:00 执行"
echo "4) 自定义（手动编辑 crontab）"
echo ""
read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        CRON_SCHEDULE="0 3 * * *"
        DESCRIPTION="每天凌晨 3:00"
        ;;
    2)
        CRON_SCHEDULE="0 3 * * 0"
        DESCRIPTION="每周日凌晨 3:00"
        ;;
    3)
        CRON_SCHEDULE="0 3 1 * *"
        DESCRIPTION="每月1号凌晨 3:00"
        ;;
    4)
        echo -e "${YELLOW}请手动编辑 crontab:${NC}"
        echo "运行: crontab -e"
        echo "添加: 0 3 * * 0 $CLEANUP_SCRIPT"
        exit 0
        ;;
    *)
        echo -e "${RED}无效选项${NC}"
        exit 1
        ;;
esac

# 生成 crontab 条目
CRON_ENTRY="$CRON_SCHEDULE $CLEANUP_SCRIPT >> /var/log/auto-cleanup/cron.log 2>&1"

echo ""
echo -e "${BLUE}将添加以下 crontab 条目:${NC}"
echo "$CRON_ENTRY"
echo -e "${BLUE}执行频率: $DESCRIPTION${NC}"
echo ""

read -p "确认安装? (y/n): " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    # 备份现有 crontab
    crontab -l > /tmp/crontab.backup 2>/dev/null || true
    
    # 检查是否已存在相同任务
    if crontab -l 2>/dev/null | grep -q "auto_cleanup.sh"; then
        echo -e "${YELLOW}检测到已存在清理任务，将先删除旧任务${NC}"
        crontab -l 2>/dev/null | grep -v "auto_cleanup.sh" | crontab -
    fi
    
    # 添加新任务
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    
    echo ""
    echo -e "${GREEN}✓ 定期清理任务安装成功!${NC}"
    echo ""
    echo -e "${BLUE}当前 crontab 任务:${NC}"
    crontab -l
    echo ""
    echo -e "${BLUE}查看日志:${NC}"
    echo "  执行日志: /var/log/auto-cleanup/cleanup-*.log"
    echo "  Cron 日志: /var/log/auto-cleanup/cron.log"
    echo ""
    echo -e "${BLUE}手动执行:${NC}"
    echo "  $CLEANUP_SCRIPT"
    echo ""
    echo -e "${BLUE}卸载任务:${NC}"
    echo "  crontab -e  # 删除包含 'auto_cleanup.sh' 的行"
else
    echo -e "${YELLOW}已取消安装${NC}"
fi
