# 所有项目数据迁移统一方案

## 概述

所有三个项目（TPD2、Writer、Todify4）现在都支持自动数据导出和导入，已整合到单项目快捷部署流程中。

## 统一特性

### ✅ 自动数据导出
- **TPD2**: 自动导出 PostgreSQL/SQLite 数据
- **Writer**: 自动导出 SQLite 数据
- **Todify4**: 自动导出 SQLite 数据（包括配置数据库）

### ✅ 自动数据导入
- **TPD2**: 支持 `AUTO_IMPORT_DATA=true` 自动导入
- **Writer/Todify4**: 数据通过 Docker Volume 持久化，首次部署自动创建

### ✅ 统一脚本结构
所有项目都包含：
- `export-local-data.sh` - 数据导出脚本
- `import-data.sh` - 数据导入脚本（TPD2）
- `fix-network.sh` - 网络修复脚本
- `build-deploy-package.sh` - 构建脚本（自动导出数据）

## 完整流程

### 本地操作（所有项目统一）

```bash
# TPD2
cd /Volumes/Lexar/git/03T/TPD2
./deploy/build-deploy-package.sh v1.1

# Writer
cd /Volumes/Lexar/git/03T/writer
./deploy/build-deploy-package.sh latest

# Todify4
cd /Volumes/Lexar/git/03T/todify4
./deploy/build-deploy-package.sh latest
```

**自动执行**：
1. 构建 Docker 镜像
2. **自动导出本地数据** → `data/init-data.sql`
3. 打包所有文件 → `项目名-deploy-版本.tar.gz`

### 服务器操作（所有项目统一）

```bash
# 1. 解压
tar -xzf 项目名-deploy-版本.tar.gz
cd 项目名-deploy-版本

# 2. 配置（TPD2 需要设置自动导入）
vi config/.env
# TPD2: AUTO_IMPORT_DATA=true

# 3. 部署（TPD2 会自动导入数据）
./scripts/deploy.sh

# 4. 验证
./scripts/verify.sh

# 5. 修复网络（如果需要）
./scripts/fix-network.sh
```

## 数据迁移方式对比

| 项目 | 数据库类型 | 导出方式 | 导入方式 | 持久化方式 |
|------|-----------|---------|---------|-----------|
| **TPD2** | PostgreSQL/SQLite | 自动导出 SQL | 自动/手动导入 SQL | Docker Volume |
| **Writer** | SQLite | 自动导出 SQL | 手动导入（可选） | Docker Volume |
| **Todify4** | SQLite | 自动导出 SQL | 手动导入（可选） | Docker Volume |

## 数据导入选项

### TPD2（PostgreSQL）

**自动导入**（推荐）：
```bash
# 在 config/.env 中设置
AUTO_IMPORT_DATA=true

# 部署时自动导入
./scripts/deploy.sh
```

**手动导入**：
```bash
./scripts/import-data.sh ../data/init-data.sql
```

### Writer/Todify4（SQLite）

**自动创建**（推荐）：
- 数据通过 Docker Volume 持久化
- 首次部署自动创建数据库
- 无需手动导入

**手动导入**（如果需要恢复）：
```bash
# Writer
docker cp ../data/init-data.sql writer-backend:/tmp/import-data.sql
docker exec writer-backend sqlite3 /app/data/writer.db < /tmp/import-data.sql

# Todify4
docker cp ../data/init-data.sql todify4-backend:/tmp/import-data.sql
docker exec todify4-backend sqlite3 /app/data/todify2.db < /tmp/import-data.sql
```

## 关键文件

### 构建脚本
- `deploy/build-deploy-package.sh` - 自动导出数据

### 数据脚本
- `deploy/export-local-data.sh` - 本地数据导出
- `deploy/import-data.sh` - 服务器数据导入（TPD2）

### 部署脚本
- `deploy/deploy.sh` - 支持自动数据导入（TPD2）
- `deploy/fix-network.sh` - 网络修复

## 注意事项

1. **数据备份**: 导入前建议备份现有数据
2. **配置更新**: 生产环境必须修改密码和密钥
3. **网络修复**: 如果通过 Unified Portal 访问，需要运行 `fix-network.sh`
4. **数据兼容性**: SQLite 导出的 SQL 可能需要手动调整以适配 PostgreSQL（TPD2）

## 完整检查清单

### 本地操作
- [ ] 运行构建脚本
- [ ] 检查数据文件是否导出（`data/init-data.sql`）
- [ ] 上传部署包到服务器

### 服务器操作
- [ ] 解压部署包
- [ ] 检查数据文件
- [ ] 配置环境变量（TPD2: `AUTO_IMPORT_DATA=true`）
- [ ] 执行部署
- [ ] 验证数据导入
- [ ] 修复网络（如果需要）
- [ ] 验证访问

## 统一优势

1. **自动化**: 数据导出和导入完全自动化
2. **一致性**: 三个项目使用相同的流程和脚本结构
3. **灵活性**: 支持自动和手动两种导入方式
4. **可靠性**: 提供完整的验证和故障排查工具
