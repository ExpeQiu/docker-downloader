============================================================
  OpenSSL 1.1 离线修复包
============================================================

【问题】
  Unified Portal 健康检查返回 500 错误
  原因: Prisma 引擎缺少 libssl.so.1.1 库

【快速修复】
  1. tar -xvf openssl-fix.tar
  2. cd openssl-fix
  3. chmod +x fix.sh
  4. ./fix.sh

【验证】
  访问: http://<服务器IP>/api/health
  应返回: 200 OK

【包含文件】
  ✓ fix.sh                   一键修复脚本
  ✓ openssl1.1-compat.apk    Alpine 3.18 离线安装包
  ✓ README.txt               本说明文件

【注意事项】
  - 确保 portal-frontend 容器正在运行
  - 修复过程会自动重启容器
  - 无需网络连接，完全离线操作

============================================================
