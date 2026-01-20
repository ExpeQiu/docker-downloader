# Todify4 离线部署指南

本指南参考 `DEPLOYMENT_MASTER_GUIDE.md`，针对 Todify4 子系统进行适配。

## 1. 准备工作 (本地)

在 `docker/` 目录下执行构建脚本：

```bash
cd docker
chmod +x build_offline.sh
./build_offline.sh
```

这将生成 `todify4-all.tar` 镜像包。

## 2. 服务器部署

### 2.1 文件传输
将以下文件上传到服务器目录 (例如 `/opt/unified-deploy/todify4/`)：

1. `todify4-all.tar`
2. `docker-compose.prod.yml` -> 重命名为 `docker-compose.yml`
3. `nginx.conf` (从 `todify4/docker/nginx.conf` 获取)

### 2.2 目录准备
在服务器上创建数据目录：

```bash
mkdir -p data uploads
chmod 777 data uploads  # 确保容器可写
```

### 2.3 加载镜像
```bash
docker load -i todify4-all.tar
```

### 2.4 启动服务
```bash
docker-compose up -d
```

### 2.5 验证
访问: `http://<服务器IP>:8118/`

## 3. 常见问题 (OpenSSL)

如果遇到 502 错误或 `libssl.so.1.1` 缺失错误 (常见于 Alpine 镜像)，请参考主指南中的 OpenSSL 修复步骤。
Todify4 的后端和 Nginx 均基于 Alpine。

如果需要修复：
1. 确保你有 `openssl-fix.tar` (从主部署包获取)。
2. 解压并执行修复命令 (针对 todify4 容器)：

```bash
# 示例：修复 todify4-backend (如果需要)
docker cp libssl.so.1.1 todify4-backend:/lib/
docker cp libcrypto.so.1.1 todify4-backend:/lib/
docker exec -u 0 todify4-backend chmod 755 /lib/libssl.so.1.1 /lib/libcrypto.so.1.1
docker restart todify4-backend
```
