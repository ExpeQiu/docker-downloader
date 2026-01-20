# 阿里云服务器自动清理方案

## 脚本说明

### 1. auto_cleanup.sh - 自动清理脚本
智能清理服务器资源，释放磁盘空间，保护运行中的服务。

**功能特性：**
- ✅ 智能阈值检测（磁盘使用率超过 80% 才执行）
- ✅ 清理 Docker 资源（容器、镜像、卷、构建缓存）
- ✅ 清理系统日志（保留最近 7 天）
- ✅ 清理应用日志（仅清理 >100MB 且 >30天的日志）
- ✅ 清理包管理器缓存
- ✅ 清理临时文件
- ✅ 详细日志记录
- ✅ 清理前后状态对比

### 2. install_cleanup_cron.sh - 定时任务安装器
快速配置定期自动清理任务。

## 使用方法

### 方式一：手动执行（推荐先测试）

#### 在本地执行（通过 SSH）
```bash
# 1. 上传脚本到服务器
scp auto_cleanup.sh root@47.113.225.93:/root/

# 2. 通过 SSH 执行
sshpass -p 'Qb89100820' ssh root@47.113.225.93 "bash /root/auto_cleanup.sh"
```

#### 在服务器上执行
```bash
# 1. SSH 登录服务器
sshpass -p 'Qb89100820' ssh root@47.113.225.93

# 2. 执行清理脚本
bash /root/auto_cleanup.sh

# 或赋予执行权限后直接运行
chmod +x /root/auto_cleanup.sh
/root/auto_cleanup.sh
```

### 方式二：配置定时任务（推荐生产环境）

#### 步骤 1：上传脚本
```bash
# 上传两个脚本到服务器
scp auto_cleanup.sh install_cleanup_cron.sh root@47.113.225.93:/root/
```

#### 步骤 2：安装定时任务
```bash
# SSH 登录服务器
sshpass -p 'Qb89100820' ssh root@47.113.225.93

# 运行安装脚本
cd /root
chmod +x install_cleanup_cron.sh
./install_cleanup_cron.sh
```

#### 步骤 3：选择执行频率
脚本会提示选择：
1. 每天凌晨 3:00 执行（适合高负载服务器）
2. **每周日凌晨 3:00 执行（推荐）**
3. 每月1号凌晨 3:00 执行（适合低负载服务器）
4. 自定义

## 清理项目详情

| 序号 | 清理项目 | 清理条件 | 风险等级 |
|------|---------|---------|---------|
| 1 | 停止的容器 | 状态为 Exited | 低 |
| 2 | 悬空镜像 | 标签为 <none> | 低 |
| 3 | 未使用的卷 | 未被任何容器使用 | 低 |
| 4 | 构建缓存 | Docker 构建缓存 | 低 |
| 5 | 包缓存 | DNF/YUM/APT 缓存 | 低 |
| 6 | 系统日志 | >7天的 journal 日志 | 低 |
| 7 | 应用日志 | >100MB 且 >30天 | 低 |
| 8 | 临时文件 | /tmp 下 >7天的文件 | 低 |
| 9 | 清理日志 | 保留最近10次日志 | 低 |

## 安全保护机制

### 1. 智能阈值检测
- 仅在磁盘使用率 > 80% 时执行清理
- 避免不必要的清理操作

### 2. 服务保护
- **不清理运行中的容器**
- **不清理被使用的镜像**
- **不清理被挂载的卷**
- **不影响 PM2 服务**

### 3. 保守清理策略
- 日志保留 7 天（系统日志）
- 应用日志仅清理 >100MB 且 >30天
- 临时文件保留 7 天

### 4. 详细日志记录
- 每次清理生成独立日志文件
- 记录清理前后对比
- 保留最近 10 次清理日志

## 日志查看

### 清理日志位置
```bash
/var/log/auto-cleanup/cleanup-YYYYMMDD-HHMMSS.log
```

### 查看最新日志
```bash
# 查看最新清理日志
ls -t /var/log/auto-cleanup/cleanup-*.log | head -1 | xargs cat

# 查看 cron 执行日志
tail -f /var/log/auto-cleanup/cron.log
```

### 查看清理历史
```bash
# 列出所有清理记录
ls -lh /var/log/auto-cleanup/cleanup-*.log

# 查看清理统计
grep "释放磁盘空间" /var/log/auto-cleanup/cleanup-*.log
```

## 监控与告警（可选）

### 添加钉钉/企业微信通知
编辑 `auto_cleanup.sh`，在 `send_notification()` 函数中添加：

```bash
send_notification() {
    local message="$1"
    local webhook_url="https://your-webhook-url"
    
    curl -X POST "$webhook_url" \
        -H 'Content-Type: application/json' \
        -d "{\"text\": \"$message\"}"
}
```

## 故障排查

### 问题 1：脚本无执行权限
```bash
chmod +x /root/auto_cleanup.sh
```

### 问题 2：Docker 命令失败
检查 Docker 服务状态：
```bash
systemctl status docker
```

### 问题 3：日志目录无法创建
检查权限：
```bash
mkdir -p /var/log/auto-cleanup
chmod 755 /var/log/auto-cleanup
```

### 问题 4：Cron 任务未执行
检查 crontab 配置：
```bash
crontab -l
```

查看 cron 日志：
```bash
grep auto_cleanup /var/log/cron
```

## 卸载定时任务

```bash
# 编辑 crontab
crontab -e

# 删除包含 'auto_cleanup.sh' 的行
# 或者直接删除所有任务
crontab -r
```

## 手动清理命令参考

如需手动清理特定项目：

```bash
# 清理停止容器
docker container prune -f

# 清理悬空镜像
docker image prune -f

# 清理所有未使用镜像（谨慎！）
docker image prune -a -f

# 清理未使用卷
docker volume prune -f

# 清理构建缓存
docker builder prune -f

# 清理所有 Docker 资源（危险！）
docker system prune -a --volumes -f

# 清理系统日志
journalctl --vacuum-time=7d

# 清理包缓存
dnf clean all  # OpenCloudOS/CentOS/RHEL
```

## 性能影响

- **执行时间**: 通常 2-5 分钟
- **CPU 影响**: 低（主要是 I/O 操作）
- **内存影响**: 可忽略
- **服务影响**: 无（不影响运行中服务）

## 最佳实践

1. **首次使用**：先手动执行，确认效果
2. **频率建议**：每周执行一次
3. **监控告警**：配置通知，及时了解清理结果
4. **日志审查**：定期检查清理日志
5. **备份策略**：清理前确保重要数据已备份

## 更新记录

- 2026-01-15: 初始版本，支持基础清理功能
- 智能阈值检测
- 详细日志记录
- 安全保护机制

## 技术支持

如有问题，请查看日志文件或联系管理员。
