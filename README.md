# Docker Image Downloader Project

这个项目专门用于解决在受限网络环境下无法拉取 Docker 镜像的问题。
利用 GitHub Actions 的高速网络，在云端下载并打包镜像，然后通过 Artifacts 下载到本地。

## 🚀 使用方法

1.  **Fork 或 Push 此仓库** 到您的 GitHub 账号。
2.  进入仓库页面，点击顶部的 **Actions** 标签。
3.  在左侧选择 **Universal Docker Image Downloader**。
4.  点击右侧的 **Run workflow** 按钮。
5.  **输入参数**：
    *   `images`: 想要下载的镜像列表，用空格分隔。
        *   例如: `node:20-alpine nginx:alpine mysql:8.0`
    *   `platform`: 目标架构。
        *   默认为 `linux/amd64` (大多数服务器使用)。
        *   如果是 M1/M2 Mac 本地使用，可填 `linux/arm64`。
6.  点击 **Run workflow** 开始下载。

## 📦 获取镜像

1.  等待 Action 运行完成（通常 1-2 分钟）。
2.  点击运行记录。
3.  在页面底部的 **Artifacts** 区域下载 `downloaded-images` 压缩包。
4.  解压后得到 `.tar.gz` 文件。

## 📥 本地导入

在本地终端执行：

```bash
# 解压
gunzip docker-images-xxx.tar.gz

# 导入 Docker
docker load -i docker-images-xxx.tar
```

## 🛠 原理

利用 GitHub Actions 托管的 Runner（通常位于 Azure 数据中心），它们拥有极佳的国际网络带宽，可以无障碍访问 Docker Hub。
