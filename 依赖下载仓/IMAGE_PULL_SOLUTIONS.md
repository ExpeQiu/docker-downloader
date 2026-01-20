# Docker 镜像拉取失败解决方案与对策

针对 "镜像容易拉取失败" 的问题，这里汇总了全渠道的解决方案，分为 **构建阶段 (Build)** 和 **部署阶段 (Deploy)** 两个维度。

## 一、 部署阶段（服务器拉取失败）

这是最常见的问题，表现为服务器无法从阿里云镜像仓库拉取镜像。

### 1. 自动重试机制 (已集成到 build.sh)
网络抖动是常态。我们在 `build.sh` 中增加了重试逻辑，当 `docker-compose pull` 失败时，脚本会自动尝试多次（默认 5 次），每次间隔 5 秒。
**对策**：确保使用最新的 `build.sh` 进行部署。

### 2. 配置镜像加速器 (Registry Mirrors)
即使是拉取阿里云私有镜像，配置合理的镜像加速器也有助于提升整体 Docker 守护进程的网络稳定性。
**操作**：
在服务器上编辑 `/etc/docker/daemon.json`：
```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://mirror.baidubce.com",
    "https://docker.nju.edu.cn"
  ]
}
```
然后重启 Docker: `sudo systemctl daemon-reload && sudo systemctl restart docker`

### 3. 使用阿里云 VPC 内网端点 (推荐)
如果你使用的是阿里云 ECS，且与镜像仓库在同一地域（如都在 广州），应使用 VPC 内网地址。
**注意**：个人版实例 (CRPI) 可能没有独立的 VPC 域名，通常自动通过公网域名解析。如果是企业版实例，请务必使用 `xxxx-vpc.cn-guangzhou.aliyuncs.com` 格式的域名，速度快且免费。

### 4. 离线部署 (兜底方案)
当所有网络手段都失效时，使用“物理”传输方式。
**原理**：本地构建 -> 保存为 .tar 文件 -> SCP 上传 -> 服务器加载。
**操作**：
我们提供了专门的脚本 `docker/build_offline.sh`。
```bash
cd docker
./build_offline.sh
# 脚本会自动处理 save/scp/load 流程
```

### 5. 修改 DNS 配置
有时是 DNS 解析超时导致的。
**操作**：
修改 `/etc/resolv.conf`，增加阿里云 DNS：
```
nameserver 223.5.5.5
nameserver 223.6.6.6
```

---

## 二、 构建阶段（本地/CI 拉取基础镜像失败）

表现为 `docker build` 时拉取 `node:20-alpine` 等官方镜像超时。

### 1. 使用国内镜像源 (已集成)
我们在 `Dockerfile` 中已经配置了 Alpine 和 NPM 的国内源（阿里云/淘宝源）。
```dockerfile
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN npm config set registry https://registry.npmmirror.com
```

### 2. 基础镜像预拉取 (Pre-pull)
`build.sh` 脚本会在构建前尝试预先拉取基础镜像。如果官方源失败，建议手动指定国内镜像源。
例如，使用 DaoCloud 镜像源替换官方源：
```bash
docker pull m.daocloud.io/docker.io/library/node:20-alpine
docker tag m.daocloud.io/docker.io/library/node:20-alpine node:20-alpine
```

### 3. 使用代理 (Proxy)
如果本地有梯子，可以为 Docker 配置代理。
**Desktop 用户**：在 Docker Desktop 设置 -> Resources -> Proxies 中配置。
**Linux 用户**：
创建 `/etc/systemd/system/docker.service.d/http-proxy.conf`：
```ini
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
```

## 三、 诊断工具

如果问题持续，请在服务器上运行以下命令诊断：

1. **测试网络连通性**：
   ```bash
   ping crpi-c6gwhxgtx8ccdxfl.cn-guangzhou.personal.cr.aliyuncs.com
   ```
2. **测试登录**：
   ```bash
   docker login crpi-c6gwhxgtx8ccdxfl.cn-guangzhou.personal.cr.aliyuncs.com
   ```
3. **查看 Docker 日志**：
   ```bash
   journalctl -u docker -n 100
   ```
