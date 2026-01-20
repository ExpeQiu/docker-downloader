# Agent Cloud Deployment Guide

This guide consolidates deployment information for Alibaba Cloud (阿里云) and Tencent Cloud (腾讯云) servers. It is designed to assist the Agent in deploying projects safely and efficiently.

## 1. Server Access Information

### 🟢 Alibaba Cloud (阿里云)
*   **IP**: `47.113.225.93`
*   **User**: `root`
*   **OS**: OpenCloudOS (yum/dnf)
*   **Quick SSH**:
    ```bash
    sshpass -p 'Qb89100820' ssh -o StrictHostKeyChecking=no root@47.113.225.93
    ```

### 🔵 Tencent Cloud (腾讯云)
*   **IP**: `111.230.58.40`
*   **User**: `root`
*   **OS**: OpenCloudOS 9.4
*   **Quick SSH**:
    ```bash
    sshpass -p 'Qb89100820' ssh -o StrictHostKeyChecking=no root@111.230.58.40
    ```

---

## 2. Deployment Strategies

### A. Non-Docker Deployment (PM2)
*Best for Node.js / Next.js / Simple Web Services*

1.  **Local Build**:
    *   Build the production version locally (e.g., `npm run build`).
2.  **Package & Upload**:
    *   Compress build artifacts (e.g., `.next`, `public`, `package.json`, `ecosystem.config.js`).
    *   Upload via SCP.
3.  **Server Setup**:
    *   Ensure Node.js and PM2 are installed.
    *   `npm install --production`
4.  **Start Service**:
    *   Use PM2 to manage the process:
        ```bash
        pm2 start npm --name "my-service" -- start -- -p <PORT>
        ```
    *   *Note*: Ensure the port does not conflict with existing services.

### B. Docker Deployment
*Best for Complex Stacks, Databases, Third-party Tools (e.g., Dify)*

1.  **Configuration**:
    *   Prepare `docker-compose.yml`.
2.  **Upload**:
    *   SCP the configuration files to a dedicated directory (e.g., `/opt/my-app/`).
3.  **Launch**:
    ```bash
    docker compose up -d
    ```

4.  **Multi-Architecture & Development Workflow (Critical)**
    *   **Context**: Local environment is Mac mini (ARM64), while Cloud Servers are AMD64 (x86_64).
    *   **Workflow Optimization**:
        1.  **Phase 1: Local Development (Native ARM64)**
            *   **Action**: Use native ARM64 architecture for all local services (portal, postgres, redis, etc.).
            *   **Benefit**: Maximizes performance and avoids emulation overhead on Mac Silicon.
            *   **Instruction**: Do NOT add `platform: linux/amd64` in `docker-compose.yml` during development. Verify all logic locally first.
        2.  **Phase 2: Production Deployment (Target x86_64)**
            *   **Action**: When ready to deploy to Alibaba/Tencent Cloud, build specifically for `linux/amd64`.

    *   **⚠️ Apple Silicon Caveat**: Docker Desktop on Apple Silicon uses manifest negotiation. Running `docker pull --platform linux/amd64` (or simple builds) may return an existing local `arm64` image if cached (indicated by "Image is up to date").

    *   **Production Build Solutions (for AMD64 Servers)**:
        *   **Prerequisite (Buildx Setup)**:
            Initialize a multi-arch builder (run once):
            ```bash
            docker buildx create --use --name multiarch-builder
            docker buildx inspect --bootstrap
            ```
        *   **Option 1 (Direct Tar Export - Recommended)**:
            Bypasses the `docker save` "content digest not found" error on Mac Silicon.
            ```bash
            docker buildx build --platform linux/amd64 -t <image_name> --output type=docker,dest=./<image_name>.tar .
            ```
        *   **Option 2 (Docker Buildx - Load)**:
            Use `buildx` to force clean multi-arch builds. *Warning: May fail with `docker save` on some versions.*
            ```bash
            docker buildx build --platform linux/amd64 -t <image_name> --load .
            ```
            *Note*: `--load` saves the image to your local Docker daemon. Use `--push` to upload directly to a registry.
        *   **Option 3 (Docker Compose - Config Change)**:
            Add `platform: linux/amd64` to your service definition in `docker-compose.yml` specifically for the production build/push step.
        *   **Option 4 (Command Line - Basic)**:
            ```bash
            docker build --platform linux/amd64 -t <image_name> .
            ```
        *   **Option 5 (Env Var)**:
            Set `export DOCKER_DEFAULT_PLATFORM=linux/amd64` before building.

---

## 3. Port Management & Existing Services

**⚠️ CRITICAL**: Before deploying, always check for port conflicts using `netstat -tulpn | grep <PORT>`.

### 🟢 Alibaba Cloud Existing Ports
| Port | Service | Type | Note |
| :--- | :--- | :--- | :--- |
| **80/443** | Nginx / Dify | System | Main Web Entry |
| **8888** | BT Panel | System | Management Panel |
| **9898** | todify 1.0 | PM2 | Active |
| **8088** | todify2 | PM2 | Active |
| **8089** | todify3 | PM2 | Active |
| **7777** | AI Canvas | PM2 | Active |
| **5003** | Dify Plugin | Docker | |
| **9999** | Dify Nginx | Docker | |
| **5555** | Prisma Studio | Node | |
| **3306** | MySQL | DB | |
| **5432** | PostgreSQL | DB | Local |
| **6379** | Redis | DB | |

### 🔵 Tencent Cloud Existing Ports
| Port | Service | Type | Note |
| :--- | :--- | :--- | :--- |
| **80** | Nginx | System | Main Web Entry |
| **8888** | BT Panel | System | Management Panel |
| **5678** | TPD Docs | PM2/Nginx | |
| **3000** | Translate3 | PM2 | Next.js Frontend |
| **3010** | TPD Backend | Node | |
| **4000** | MiniProgram | Node | |
| **8000** | Translate App | Docker | |
| **8001** | Backend App | Docker | |
| **5432** | Postgres | Docker | Translate DB |
| **5433** | Postgres | Docker | Backend DB |
| **6379** | Redis | Docker | Translate Cache |
| **8099, 887, 888, 1111** | Nginx Proxies | Nginx | Various proxies |

---

## 4. Operation Guidelines for Agent

1.  **Safety First**:
    *   Do not stop `nginx`, `sshd`, or `bt` (Baota Panel) services.
    *   Do not overwrite existing `docker-compose.yml` files of running services (like Dify). Create new directories for new projects.

2.  **Nginx Configuration**:
    *   Servers use **Baota (宝塔) Panel** for Nginx management.
    *   *Avoid* manually editing `/etc/nginx/nginx.conf` if possible to prevent conflicts with the panel.
    *   If a reverse proxy is needed, check if a new configuration file in `conf.d` or a new server block is safe to add, or instruct the user to configure via panel if complex.

3.  **Verification**:
    *   After deployment, use `curl http://localhost:<PORT>` on the server to verify the service is running locally.
    *   Check `pm2 list` or `docker ps` to ensure process stability.

---

## 5. Deployment Efficiency & Acceleration (Optimization)

### A. Docker Image Acceleration (Domestic Mirrors)
To speed up image pulls on Alibaba/Tencent Cloud servers within China:

1.  **Configure Daemon**: Edit `/etc/docker/daemon.json`.
    ```json
    {
      "registry-mirrors": [
        "https://registry.cn-hangzhou.aliyuncs.com",
        "https://mirror.ccs.tencentyun.com"
      ]
    }
    ```
2.  **Restart Docker**:
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    ```

### B. Build-Time Dependency Acceleration
Speed up `docker build` by using domestic mirrors for package managers.

1.  **NPM / Node.js**:
    ```dockerfile
    # Use .npmrc for better compatibility and specific binary mirrors (sqlite3)
    RUN echo "registry=https://registry.npmmirror.com" > .npmrc && \
        echo "sqlite3_binary_host_mirror=https://npmmirror.com/mirrors/sqlite3" >> .npmrc
    ```
2.  **Python (Pip)**:
    ```dockerfile
    RUN pip install -i https://mirrors.aliyun.com/pypi/simple/ -r requirements.txt
    ```
3.  **Debian/Ubuntu (apt)**:
    Replace sources.list with Aliyun or Tencent mirrors in Dockerfile.
    ```dockerfile
    RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list
    ```
4.  **Alpine (apk)**:
    ```dockerfile
    RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
    ```

### C. Development & Update Strategy
1.  **Layer Caching**:
    *   Copy dependency files (`package.json`, `requirements.txt`) **before** source code.
    *   Run install commands.
    *   Copy source code (`COPY . .`).
    *   *Benefit*: Re-building only changes the source layer, not downloading dependencies again.
2.  **Small Base Images**:
    *   Use `alpine` or `slim` variants (e.g., `node:18-alpine`, `python:3.10-slim`) to reduce transfer time.
3.  **.dockerignore**:
    *   Always exclude `node_modules`, `.git`, `.env` to prevent huge build contexts.

## 6. Troubleshooting & Common Pitfalls (Mac Specific)

### A. "Content Digest Not Found" during `docker save`
When building `linux/amd64` images on Apple Silicon using `docker buildx build --load`, executing `docker save` immediately after might fail with "content digest not found".
**Fix**: Skip `docker save` and export the tarball directly using `buildx`:
```bash
docker buildx build --platform linux/amd64 -t app:v1 --output type=docker,dest=app.tar .
```

### B. "xattr: operation not permitted" on External Drives
If working from an external drive (exFAT/NTFS) on macOS, Docker may fail to copy context due to hidden metadata files (`._*`).
**Fix**: Clean them up before building:
```bash
find . -name "._*" -delete
```
