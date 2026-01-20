# 堡垒机 Docker 部署主指南 (Master Deployment Guide)

本指南整合了 Unified Portal 及各子系统的最佳部署实践，并包含了针对 OpenSSL 兼容性问题的修复步骤。

## 📋 1. 部署前准备

### 1.1 本地环境要求
- **Docker Desktop**: 需支持 `buildx`（用于跨平台构建）。
- **架构注意**: 如果使用 Mac (M1/M2/M3)，**必须**指定 `--platform linux/amd64`，否则镜像在服务器上无法运行。

### 1.2 构建镜像
在项目根目录下执行：

> **💡 网络优化提示 (国内环境)**: 
> 如果遇到 `pull access denied` 或拉取缓慢，可使用 DaoCloud 加速镜像：
> *   `node:20-alpine` -> `m.daocloud.io/docker.io/library/node:20-alpine`
> *   `postgres:15-alpine` -> `m.daocloud.io/docker.io/library/postgres:15-alpine`
> *   `redis:7-alpine` -> `m.daocloud.io/docker.io/library/redis:7-alpine`
>
> **⚠️ 跨平台构建警告 (Mac M1/M2/M3)**:
> 在 Mac 上使用 `buildx --load` 后再 `docker save` 可能会报错 `NotFound: content digest ... not found`。
> **强烈建议**使用 `--output type=docker,dest=./filename.tar` 直接导出 tar 包流。

```bash
# 1. 构建前端镜像 (推荐方式：直接导出 tar，规避 docker save 错误)
# 如果 Dockerfile 支持 ARG BASE_IMAGE，可添加: --build-arg BASE_IMAGE=m.daocloud.io/...
docker buildx build --platform linux/amd64 \
  -t unified-portal-frontend:v1.0 \
  --output type=docker,dest=./unified-portal-frontend.tar \
  .

# 2. 拉取依赖镜像 (确保指定平台)
# 建议先测试 DaoCloud 连接，如果超时则回退到官方源
docker pull --platform linux/amd64 postgres:15-alpine
docker save -o postgres.tar postgres:15-alpine

docker pull --platform linux/amd64 redis:7-alpine
docker save -o redis.tar redis:7-alpine

# 3. 合并镜像包 (使用 tar 命令)
tar -cvf unified-portal-all.tar \
  unified-portal-frontend.tar \
  postgres.tar \
  redis.tar

# 清理临时 tar 文件
rm unified-portal-frontend.tar postgres.tar redis.tar
```

---

## 🚀 2. 传输文件到服务器

通过堡垒机或直接使用 SFTP 将以下文件上传到服务器（建议目录 `/opt/unified-deploy/`）：

1.  `unified-portal-all.tar` (镜像包)
2.  `docker-compose.yml` (编排文件)
3.  `openssl-fix.tar` (OpenSSL 修复包，**关键**)

> **提示**: 如果文件过大，建议使用 SFTP 客户端（如 WindTerm/FileZilla）而不是 `rz` 命令。

---

## ⚙️ 3. 服务器端部署

### 3.1 加载镜像
```bash
docker load -i unified-portal-all.tar
```

### 3.2 启动服务
确保端口未被占用（8300, 5435, 6380, 80）。

```bash
# 使用 docker-compose 启动 (推荐)
docker-compose up -d

# 或者使用 docker run 手动启动 (参考 archive/Unified Portal...md)
```

### 3.3 验证初步状态
```bash
docker ps
# 检查容器是否为 Up 状态
```

---

## 🔧 4. 关键修复与故障排除

### 4.1 构建阶段：`docker save` 报错 (Content Digest Not Found)
如果在导出镜像时遇到以下错误：
`Error response from daemon: unable to create manifests file: NotFound: content digest sha256:... not found`

**原因**: Mac Docker Desktop 在跨平台构建 (`linux/amd64`) 时，`buildx` 的 `--load` 参数可能导致元数据未正确同步到宿主机 daemon，导致 `docker save` 无法找到对应的层。

**解决方案**:
彻底放弃 `docker save`，改用 `buildx` 的 `--output type=docker` 直接导出 tar 包。这适用于业务镜像和基础镜像：

```bash
# 1. 导出业务镜像
docker buildx build --platform linux/amd64 -t <image_name> --output type=docker,dest=./<image_name>.tar .

# 2. 导出基础镜像 (如 nginx, postgres) - 使用动态 Dockerfile
docker buildx build --platform linux/amd64 -t nginx:alpine --output type=docker,dest=./nginx.tar - <<EOF
FROM nginx:alpine
EOF
```

### 4.2 构建阶段：`xattr` 权限错误 (外接磁盘问题)
**现象**: `failed to xattr .../._filename: operation not permitted`
**原因**: 在 macOS 外接磁盘 (exFAT/NTFS) 上进行 Docker 构建时，守护进程无法处理 macOS 生成的隐藏元数据文件 (`._*`) 的扩展属性。
**解决方案**:
1. 将临时 Dockerfile 生成到 `/tmp` 目录（系统盘）。
2. 在构建前清理项目目录中的元数据文件：
```bash
find . -name "._*" -delete
```

### 4.3 构建阶段：`sqlite3` / NPM 安装超时
**现象**: `npm ci` 或 `npm install` 卡在 `reify:sqlite3: timing downlaod` 或报错。
**原因**: `sqlite3` 等原生模块需要下载预编译二进制包，默认 GitHub 源在国内访问极慢。
**解决方案**:
在 Dockerfile 中通过 `.npmrc` 配置镜像源（注意：某些 npm 版本不支持直接通过命令行 config set 设置非标准字段，建议写入文件）：
```dockerfile
RUN echo "registry=https://registry.npmmirror.com" > .npmrc && \
    echo "sqlite3_binary_host_mirror=https://npmmirror.com/mirrors/sqlite3" >> .npmrc && \
    echo "disturl=https://npmmirror.com/mirrors/node" >> .npmrc
```

### 4.4 部署阶段：OpenSSL/502 问题

部署后，如果访问出现 **502 Bad Gateway** 或容器日志报错 `Error loading shared library libssl.so.1.1`，请执行以下修复步骤。这是由于 Alpine 镜像缺少旧版 OpenSSL 库导致的。

#### 4.2.1 解压修复包
```bash
tar -xvf openssl-fix.tar
cd openssl-fix
```

#### 4.2.2 执行修复 (推荐手动方式，确保容器名正确)
由于容器名称可能是 `unified-portal-frontend`，建议直接执行以下命令：

```bash
# 1. 复制库文件到容器 (同时复制到 /lib 和 /usr/lib 以防万一)
docker cp libssl.so.1.1 unified-portal-frontend:/lib/
docker cp libcrypto.so.1.1 unified-portal-frontend:/lib/
docker cp libssl.so.1.1 unified-portal-frontend:/usr/lib/
docker cp libcrypto.so.1.1 unified-portal-frontend:/usr/lib/

# 2. 设置权限
docker exec -u 0 unified-portal-frontend chmod 755 /lib/libssl.so.1.1 /lib/libcrypto.so.1.1
docker exec -u 0 unified-portal-frontend chmod 755 /usr/lib/libssl.so.1.1 /usr/lib/libcrypto.so.1.1

# 3. 重启容器
docker restart unified-portal-frontend
```

#### 4.2.3 验证修复
```bash
docker exec unified-portal-frontend ls -lh /lib/libssl.so.1.1
# 应显示文件信息
```

---

## ✅ 5. 最终验证

访问以下接口确认服务正常：

1.  **健康检查**: `http://<服务器IP>/api/health` (应返回 200 OK)
2.  **主页**: `http://<服务器IP>/`
3.  **子系统**:
    - TPD2: `http://<服务器IP>/tpd2/`
    - Writer: `http://<服务器IP>/writer/`
    - Todify4: `http://<服务器IP>/todify/`

---

## 📂 附录：文档索引
详细的背景信息和历史记录请查阅 `archive/` 目录：
- `Unified Portal 堡垒机 Docker 服务部署计划.md`: 完整的架构和配置说明。
- `FIX_SUCCESS.md`: 修复方案的验证记录。
