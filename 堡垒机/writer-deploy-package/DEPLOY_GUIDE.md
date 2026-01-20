# Writer 项目独立部署指南

## 1. 部署包完整性检查
确保目录中包含以下文件：
- `docker-compose.yml`: 服务编排文件 (已配置 geely-net 和 IP 10.133.23.136)
- `.env`: 环境变量文件 (包含 API Key 和数据库配置)
- `save_images.sh`: 镜像导出脚本 (辅助工具)
- `load_images.sh`: 镜像导入脚本 (辅助工具)

## 2. 准备镜像 (在本地执行)

### 2.1 构建镜像 (如果本地没有镜像)
首先需要从源码构建镜像：

```bash
cd /Volumes/Lexar/git/07Docker/堡垒机/writer-deploy-package
./build_images.sh
```

### 2.2 导出镜像
构建完成后，导出镜像为 tar 包：

```bash
./save_images.sh
```
这将生成 `writer-images.tar` 文件。

## 3. 上传至服务器
使用 `scp` 将部署包上传至目标服务器 (10.133.23.136)：

```bash
# 假设上传到服务器的 /data/deploy 目录
scp -r /Volumes/Lexar/git/07Docker/堡垒机/writer-deploy-package root@10.133.23.136:/data/deploy/
```

## 4. 执行部署 (在服务器执行)
登录服务器并进入部署目录：

```bash
ssh root@10.133.23.136
cd /data/deploy/writer-deploy-package
```

### 4.1 导入镜像 (如果是离线部署)
```bash
./load_images.sh
```

### 4.2 启动服务
```bash
docker-compose up -d
```

### 4.3 验证部署
检查容器状态：
```bash
docker-compose ps
```
确保 `writer-backend` 和 `writer-frontend` 状态为 Up (healthy)。

## 5. 访问服务
- 前端地址: http://10.133.23.136:8218
- 后端 API: http://10.133.23.136:8228
