#!/bin/bash
set -e

# Define paths
ROOT_DIR="/Volumes/Lexar/git"
DOCKER_DIR="$ROOT_DIR/07Docker"
PROJECTS_DIR="$ROOT_DIR/03T"
DEPLOY_DIR="$DOCKER_DIR/堡垒机/unified-deploy"
OUTPUT_DIR="$DOCKER_DIR/堡垒机"

echo "=== Starting Preparation for Unified Deployment ==="

# 1. Build Unified Portal (Next.js)
echo ">>> Building Unified Portal..."
cd "$PROJECTS_DIR/GeelyTPD/unified-portal/frontend"
# Assuming Unified Portal uses relative paths or defaults, no special args needed unless specified.
docker build -t unified-portal-frontend:v1.0 .

# 2. Build TPD2 (Vite + Express)
echo ">>> Building TPD2..."
cd "$PROJECTS_DIR/TPD2/backend"
docker build -t tpd2-backend:v1.1 .

cd "$PROJECTS_DIR/TPD2/frontend"
# API Base URL must match Nginx proxy path + Backend prefix
# Nginx: /tpd2-api/ -> Backend: /
# Backend routes start with /api/...
# So we need frontend to request /tpd2-api/api/...
docker build --build-arg VITE_API_BASE_URL=/tpd2-api/api -t tpd2-frontend:v1.1 .

cd "$PROJECTS_DIR/TPD2/database"
docker build -t tpd2-postgres:v1.1 .

# 3. Build Writer (Next.js + FastAPI)
echo ">>> Building Writer..."
cd "$PROJECTS_DIR/writer/backend"
docker build -t writer-backend:latest .

cd "$PROJECTS_DIR/writer/frontend"
# Nginx: /writer-api/ -> Backend: /
# Writer backend (FastAPI) routes are at root or /api?
# Typically FastAPI docs are at /docs.
# If Writer frontend uses NEXT_PUBLIC_API_URL, we set it to /writer-api
docker build --build-arg NEXT_PUBLIC_API_URL=/writer-api -t writer-frontend:latest .

# 4. Build Todify4 (Vite + Express)
echo ">>> Building Todify4..."
cd "$PROJECTS_DIR/todify4/backend"
docker build -t todify4-backend:latest .

cd "$PROJECTS_DIR/todify4/frontend"
# Nginx: /todify-api/ -> Backend: /
# Backend routes start with /api/v1
# So frontend should request /todify-api/api/v1
docker build --build-arg VITE_API_BASE_URL=/todify-api/api/v1 -t todify4-frontend:latest .

# 5. Pull Base Images
echo ">>> Pulling Base Images..."
docker pull postgres:15-alpine
docker pull redis:7-alpine
docker pull nginx:alpine

# 6. Export Images
echo ">>> Exporting Images to $OUTPUT_DIR..."
cd "$OUTPUT_DIR"
# Remove old tar files if any
rm -f portal-imgs.tar tpd2-imgs.tar writer-imgs.tar todify4-imgs.tar

echo "Exporting Portal..."
docker save unified-portal-frontend:v1.0 postgres:15-alpine redis:7-alpine -o portal-imgs.tar

echo "Exporting TPD2..."
docker save tpd2-backend:v1.1 tpd2-frontend:v1.1 tpd2-postgres:v1.1 -o tpd2-imgs.tar

echo "Exporting Writer..."
docker save writer-backend:latest writer-frontend:latest -o writer-imgs.tar

echo "Exporting Todify4..."
docker save todify4-backend:latest todify4-frontend:latest -o todify4-imgs.tar

# 7. Package Deployment Script
echo ">>> Packaging Deployment Script..."
cd "$OUTPUT_DIR"
if [ -d "unified-deploy" ]; then
    # Ensure no hidden files like .DS_Store are included
    tar -czf unified-deploy.tar.gz unified-deploy/ --exclude='.*'
    echo "Deployment script packaged: unified-deploy.tar.gz"
else
    echo "Error: unified-deploy directory not found!"
    exit 1
fi

echo "=== Preparation Complete! ==="
echo "Files ready in $OUTPUT_DIR:"
ls -lh *.tar *.tar.gz
