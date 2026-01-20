# 使用 GitHub Actions 下载 Docker 镜像

当本地网络环境无法拉取 Docker 镜像（如 `docker pull` 超时）时，可以利用 GitHub Actions 的海外网络环境下载镜像，然后传输到本地加载。

## 方案流程

1. **GitHub 端**：运行 Workflow 下载镜像并打包为 Artifact。
2. **本地端**：下载 Artifact，解压并加载到 Docker。

## 详细步骤

### 1. 触发 GitHub Workflow

1. 进入本仓库的 **Actions** 页面。
2. 在左侧栏选择 **Universal Docker Image Downloader**。
3. 点击右侧的 **Run workflow** 按钮。
4. 在 **List of images to download** 输入框中，输入你需要下载的镜像。
   - **默认值已更新为**：`python:3.12-slim` (根据你的需求)
   - 你也可以输入其他镜像，用空格分隔，例如：`node:20-alpine nginx:latest`
5. 点击绿色 **Run workflow** 按钮开始运行。

### 2. 下载镜像文件

1. 等待 Workflow 运行完成（通常显示为绿色对勾 ✅）。
2. 点击运行记录进入详情页。
3. 在底部的 **Artifacts** 区域，点击 `downloaded-images` 进行下载。
   - 这将下载一个 `.zip` 压缩包。

### 3. 加载镜像到本地

1. 将下载的 `.zip` 文件移动到本目录 (`/Volumes/Lexar/git/07Docker/依赖下载仓`).
2. 运行我们提供的自动化脚本：

```bash
cd /Volumes/Lexar/git/07Docker/依赖下载仓
./load_image.sh
```

脚本会自动：
- 解压 zip 文件
- 找到 `docker-images-*.tar.gz`
- 执行 `docker load` 将镜像导入本地 Docker 环境

### 4. 验证

加载完成后，你可以运行以下命令验证镜像是否存在：

```bash
docker images | grep python
```

应该能看到 `python:3.12-slim`。

---

**注意**：Artifact 下载链接通常有有效期（默认 retention-days: 3），请及时下载。
