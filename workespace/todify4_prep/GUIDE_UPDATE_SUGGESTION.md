# 堡垒机 Docker 部署主指南 (Master Deployment Guide) 更新建议

由于权限限制，我无法直接修改 `/Volumes/Lexar/git/07Docker/堡垒机/DEPLOYMENT_MASTER_GUIDE.md`。
请参考以下内容手动更新该文件，以包含最新的构建最佳实践和故障排除经验。

## 建议更新 1: 修改 "1.2 构建镜像" 部分

将原有的构建命令替换为更健壮的 `buildx` 导出方式：

```markdown
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
```

## 建议更新 2: 添加故障排除部分

在文档末尾或适当位置添加：

```markdown
## 🔧 4. 关键修复与故障排除

### 4.1 构建阶段：`docker save` 报错
如果在导出镜像时遇到以下错误：
`Error response from daemon: unable to create manifests file: NotFound: content digest sha256:... not found`

**原因**: Mac Docker Desktop 在跨平台构建 (`linux/amd64`) 时，`buildx` 的 `--load` 参数可能导致元数据未正确同步到宿主机 daemon。

**解决方案**:
不要使用 `docker save`，而是在 `docker buildx build` 时直接输出文件：
```bash
docker buildx build --platform linux/amd64 -t <image_name> --output type=docker,dest=./<image_name>.tar .
```

### 4.2 部署阶段：OpenSSL/502 问题
(保留原有 OpenSSL 修复内容...)
```
