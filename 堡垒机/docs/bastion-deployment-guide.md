# 堡垒机 Docker 服务部署技能 (Bastion Host Docker Deployment Skill)

> **说明**: 本文档中的 `program` 为占位符，指代具体的项目名称（例如 `tpd2`, `todify` 等）。在实际执行命令时，请将其替换为您项目的实际名称。

本技能指南详细描述了如何通过堡垒机上传 Docker 镜像并在云服务器上部署全套服务（数据库、后端、前端）。

**目标部署服务器 IP**: `10.133.23.136`

## 1. 环境准备与文件上传

### 1.1 文件上传
使用 `rz` 命令将本地打包好的 Docker 镜像包上传到堡垒机/服务器。

```bash
# 上传文件 (使用 -be 参数避免二进制传输错误)
rz -be
```

### 1.2 验证文件
上传完成后，验证文件是否存在及大小是否正确。

```bash
ls -lh program-all-v1.0.tar
```

## 2. Docker 环境准备

### 2.1 启动 Docker 服务
如果 Docker 未启动，需执行以下命令。

```bash
# 启动 Docker
systemctl start docker

# 设置开机自启
systemctl enable docker
```

### 2.2 验证 Docker 版本
确保 Docker 已安装且版本符合要求。

```bash
docker version
```

## 3. 镜像加载与网络配置

### 3.1 加载镜像
将上传的 tar 包还原为 Docker 镜像。

```bash
docker load -i program-all-v1.0.tar
```

### 3.2 验证镜像
```bash
docker images
```

### 3.3 创建内部网络
创建 Docker 内部网络以便容器间通过服务名通信。

```bash
docker network create program-net
```

## 4. 端口规划与服务启动

> **⚠️ 重要提示 (端口冲突风险)**
> 在启动服务前，**必须**检查服务器端口占用情况，避免与现有服务（如 Nginx, 其他 Docker 容器）或总服务器进程发生冲突。
> 
> *   **常见冲突端口**: `80`, `443`, `8000`, `8080`, `3000`, `3306`, `5432`, `6379`
> *   **检查命令**:
>     ```bash
>     # 检查所有监听端口
>     netstat -tulpn
>     
>     # 检查特定端口 (例如 8000)
>     netstat -tulpn | grep 8000
>     ```
> *   **解决冲突**: 如果目标端口已被占用，请修改 `docker run` 命令中的主机映射端口 (例如 `-p <新端口>:8000`)。

### 4.1 启动数据库 (Postgres)
```bash
docker run -d \
  --name program-postgres \
  --network program-net \
  --restart always \
  -e POSTGRES_PASSWORD=mysecretpassword \
  program-postgres:v1.0
```

### 4.2 启动后端服务 (Backend)
后端通常监听 8000 端口，并连接数据库。
**注意**: 如果 `8000` 被占用，请将 `-p 8000:8000` 修改为 `-p <可用端口>:8000`。
```bash
docker run -d \
  --name program-backend \
  --network program-net \
  --restart always \
  -p 8000:8000 \
  -e DB_HOST=program-postgres \
  -e DB_PORT=5432 \
  -e DB_PASS=mysecretpassword \
  program-backend:v1.0
```

### 4.3 启动前端服务 (Frontend)
前端通常对外暴露 80 端口。
**注意**: `80` 端口通常被 Nginx 或其他 Web 服务占用。建议映射到其他端口（如 `8081`），或通过 Nginx 反向代理访问。
```bash
docker run -d \
  --name program-frontend \
  --network program-net \
  --restart always \
  -p 80:80 \
  program-frontend:v1.0
```

## 5. 验证与访问

### 5.1 检查容器状态
```bash
docker ps
```

### 5.2 访问测试
假设服务器 IP 为 `10.133.23.136` (请根据实际情况调整端口)。

*   **前端访问**: 
    *   浏览器: `http://10.133.23.136:<前端映射端口>` (默认为 80)
    *   本地测试: `curl http://localhost:<前端映射端口>`
*   **后端访问**: 
    *   浏览器: `http://10.133.23.136:<后端映射端口>` (默认为 8000)
    *   本地测试: `curl http://localhost:<后端映射端口>`

## 6. 防火墙配置

确保云服务器安全组已放行您规划的 **实际映射端口**。如果服务器内部开启了防火墙 (`firewalld`)，需手动放行。

```bash
# 检查防火墙状态
systemctl status firewalld

# 开放端口 (以 80 和 8000 为例，请替换为您实际使用的端口)
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=8000/tcp
firewall-cmd --reload

# 临时关闭防火墙 (仅用于测试)
systemctl stop firewalld
```

## 7. 数据导入 (可选)

如果需要从 SQLite 迁移数据到 Postgres，请参考以下流程。

### 7.1 上传 SQL 文件
将导出的 SQL 文件上传到服务器 `/root/` 目录。

### 7.2 复制并执行导入
```bash
# 复制 SQL 文件到容器
docker cp /root/sqlite-to-postgres-*.sql program-postgres:/tmp/import-data.sql

# 执行导入
docker exec program-postgres psql -U postgres -d program -f /tmp/import-data.sql
```

## 8. 异常排查

如果服务启动失败，查看容器日志。

```bash
# 查看数据库日志
docker logs --tail 50 program-postgres

# 查看后端日志
docker logs --tail 50 program-backend

# 查看前端日志
docker logs --tail 50 program-frontend
```

---
**注意**: 本指南中的镜像名称 (`program-*`)、端口 (`8000`, `80`) 和网络名称 (`program-net`) 为示例，实际部署时请根据项目情况调整。
