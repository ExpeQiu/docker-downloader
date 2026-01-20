#!/bin/bash

# 腾讯云服务器健康检查脚本
# 服务器: root@111.230.58.40

SERVER="root@111.230.58.40"
PASSWORD="Qb89100820"

echo "=========================================="
echo "腾讯云服务器健康评估报告"
echo "服务器: 111.230.58.40"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 1. 系统基本信息
echo "【1. 系统基本信息】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "uname -a"
echo ""

# 2. 系统负载
echo "【2. 系统负载】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "uptime"
echo ""

# 3. CPU 使用情况
echo "【3. CPU 使用情况】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "top -bn1 | head -20"
echo ""

# 4. 内存使用情况
echo "【4. 内存使用情况】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "free -h"
echo ""

# 5. 磁盘使用情况
echo "【5. 磁盘使用情况】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "df -h"
echo ""

# 6. 磁盘IO情况
echo "【6. 磁盘IO情况】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "iostat -x 1 2 2>/dev/null || echo 'iostat 未安装'"
echo ""

# 7. 网络连接状态
echo "【7. 网络连接统计】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "ss -s"
echo ""

# 8. PM2 服务状态
echo "【8. PM2 服务状态】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "pm2 list 2>/dev/null || echo 'PM2 未安装或未运行'"
echo ""

# 9. Docker 容器状态
echo "【9. Docker 容器状态】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "docker ps -a 2>/dev/null || echo 'Docker 未安装'"
echo ""

# 10. Nginx 状态
echo "【10. Nginx 状态】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "systemctl status nginx --no-pager -l 2>/dev/null | head -20 || nginx -t 2>&1"
echo ""

# 11. 关键服务端口监听
echo "【11. 关键服务端口监听】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "netstat -tlnp 2>/dev/null | grep -E ':(80|443|3000|3001|3010|4000|5678|8000|8001|8008|8099|3306|5432|5433|5434|6379|6390|8888)' || ss -tlnp | grep -E ':(80|443|3000|3001|3010|4000|5678|8000|8001|8008|8099|3306|5432|5433|5434|6379|6390|8888)'"
echo ""

# 12. 系统进程数
echo "【12. 系统进程统计】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "ps aux | wc -l && echo '总进程数'"
echo ""

# 13. 系统错误日志（最近20条）
echo "【13. 系统错误日志（最近20条）】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "journalctl -p err -n 20 --no-pager 2>/dev/null || tail -20 /var/log/messages 2>/dev/null || echo '无法访问系统日志'"
echo ""

# 14. 系统安全更新
echo "【14. 系统更新检查】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "yum check-update --quiet 2>&1 | head -10 || dnf check-update --quiet 2>&1 | head -10 || echo '无法检查更新'"
echo ""

# 15. 数据库服务状态
echo "【15. 数据库服务状态】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "systemctl status postgresql --no-pager -l 2>/dev/null | head -10 || systemctl status mysql --no-pager -l 2>/dev/null | head -10 || echo '数据库服务检查'"
echo ""

# 16. Redis 服务状态
echo "【16. Redis 服务状态】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "systemctl status redis --no-pager -l 2>/dev/null | head -10 || redis-cli ping 2>/dev/null || echo 'Redis 服务检查'"
echo ""

# 17. 服务响应测试
echo "【17. 服务响应测试】"
echo "测试 TPD-技术资料管理 (5678):"
curl -s -o /dev/null -w "HTTP状态码: %{http_code}, 响应时间: %{time_total}s\n" http://111.230.58.40:5678 || echo "连接失败"
echo "测试 AI翻译-Translate3 (3000):"
curl -s -o /dev/null -w "HTTP状态码: %{http_code}, 响应时间: %{time_total}s\n" http://111.230.58.40:3000 || echo "连接失败"
echo "测试 Translate 应用 (8000):"
curl -s -o /dev/null -w "HTTP状态码: %{http_code}, 响应时间: %{time_total}s\n" http://111.230.58.40:8000 || echo "连接失败"
echo "测试 Backend 后端 (8001):"
curl -s -o /dev/null -w "HTTP状态码: %{http_code}, 响应时间: %{time_total}s\n" http://111.230.58.40:8001 || echo "连接失败"
echo "测试 TPD 后端 (3010):"
curl -s -o /dev/null -w "HTTP状态码: %{http_code}, 响应时间: %{time_total}s\n" http://111.230.58.40:3010 || echo "连接失败"
echo "测试 小程序后端 (4000):"
curl -s -o /dev/null -w "HTTP状态码: %{http_code}, 响应时间: %{time_total}s\n" http://111.230.58.40:4000 || echo "连接失败"
echo ""

# 18. 系统资源使用趋势（最近1分钟）
echo "【18. 系统资源使用趋势】"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "vmstat 1 3"
echo ""

echo "=========================================="
echo "健康检查完成"
echo "=========================================="
