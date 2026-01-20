# 通用项目文档整理脚本

## 简介

`organize-docs.sh` 是一个通用的、可移植的 Shell 脚本，用于自动识别、分类和整理项目中的各类文档文件。支持 Markdown、文本、YAML、JSON、PDF 等多种文档格式。

## 特性

- **自包含设计**：脚本内置默认配置，无需外部依赖即可运行
- **自动检测**：自动识别项目根目录和常见项目结构
- **灵活配置**：支持命令行参数和可选配置文件
- **多种分类模式**：按日期、类型、项目三种模式分类
- **安全操作**：默认复制文件（保留原文件），支持预览模式

## 快速开始

### 1. 使用脚本

```bash
# 复制脚本到项目根目录
cp organize-docs.sh /path/to/your/project/

# 添加执行权限
chmod +x organize-docs.sh

# 预览整理结果（不实际移动文件）
./organize-docs.sh --dry-run

# 执行整理（使用默认配置）
./organize-docs.sh
```

### 2. 基本使用

```bash
# 预览整理结果
./organize-docs.sh --dry-run

# 按日期分类（默认）
./organize-docs.sh --mode date

# 按类型分类
./organize-docs.sh --mode type

# 按项目分类
./organize-docs.sh --mode project

# 指定目标目录
./organize-docs.sh --target docs/archive

# 移动文件（而非复制）
./organize-docs.sh --operation move
```

## 命令行参数

```bash
./organize-docs.sh [选项]

选项:
  --dry-run              预览模式，不实际移动文件
  --interactive          交互式确认每个文件
  --verbose              显示详细日志
  --config FILE          指定配置文件（默认: .organize-docs.conf）
  --target DIR           目标目录（默认: docs）
  --mode MODE            分类模式: date|type|project（默认: date）
  --scan DIRS            扫描目录（空格分隔，覆盖默认）
  --exclude DIRS         排除目录（空格分隔，覆盖默认）
  --operation OP         文件操作: move|copy（默认: copy）
  --no-index             不生成索引文件
  --help                 显示帮助信息
```

## 分类模式

### 按日期分类（默认）

```
docs/
└── 2026/
    └── 01/
        ├── 2026-01-15_阿里云服务器分析.md
        └── 2026-01-16_项目规则.md
```

### 按类型分类

```
docs/
├── analysis/          # 分析报告
├── design/            # 设计文档
├── config/            # 配置文件文档
└── guide/             # 指南文档
```

### 按项目分类

```
docs/
├── docker/
│   └── 2026/
│       └── 01/
└── general/
    └── 2026/
        └── 01/
```

## 支持的文档类型

### 文档类
- Markdown: `.md`, `.markdown`
- 文本: `.txt`, `.text`
- ReStructuredText: `.rst`
- Org Mode: `.org`
- 富文本: `.pdf`, `.docx`, `.doc`

### 配置文件文档
- YAML: `.yml`, `.yaml`
- JSON: `.json`
- XML: `.xml`

### 项目文档
- `README*`, `CHANGELOG*`, `LICENSE*`
- `guide/**/*`, `docs/**/*`

## 配置文件

可选的配置文件 `.organize-docs.conf`（如果存在则自动加载）：

```bash
# 文档类型扩展名
DOC_EXTENSIONS="md markdown txt rst org pdf docx doc"
CONFIG_DOC_EXTENSIONS="yml yaml json xml"

# 扫描目录（空格分隔，相对于项目根目录）
SCAN_DIRS=".specstory/history docs guide ."

# 排除目录（空格分隔）
EXCLUDE_DIRS=".git node_modules .specstory dist build"

# 分类模式：date|type|project
CLASSIFY_MODE="date"

# 目标目录（相对于项目根目录）
TARGET_DIR="docs"

# 是否生成索引
GENERATE_INDEX=true

# 文件操作模式：move|copy
FILE_OPERATION="copy"
```

参考 `.organize-docs.conf.example` 获取完整配置示例。

## 使用示例

### 示例 1：整理项目文档

```bash
# 预览整理结果
./organize-docs.sh --dry-run --verbose

# 执行整理（复制文件）
./organize-docs.sh

# 移动文件到归档目录
./organize-docs.sh --target docs/archive --operation move
```

### 示例 2：自定义分类

```bash
# 按类型分类
./organize-docs.sh --mode type

# 按项目分类
./organize-docs.sh --mode project
```

### 示例 3：自定义扫描范围

```bash
# 只扫描特定目录
./organize-docs.sh --scan "guide docs"

# 排除更多目录
./organize-docs.sh --exclude ".git node_modules .cache"
```

## 输出

整理完成后，脚本会：

1. 创建目标目录结构
2. 复制或移动文档文件
3. 生成索引文件 `docs/README.md`

索引文件包含：
- 文档统计信息
- 按分类模式组织的文档列表
- 自动更新时间戳

## 注意事项

1. **默认行为**：脚本默认复制文件（`FILE_OPERATION=copy`），保留原文件
2. **预览模式**：使用 `--dry-run` 预览整理结果，不会实际移动文件
3. **项目检测**：脚本自动检测项目根目录（查找 `.git`、`package.json`、`.code-workspace` 等）
4. **文件冲突**：重名文件会自动添加序号（如 `filename_1.md`）

## 跨项目使用

脚本设计为可复制到任何项目：

```bash
# 方式1：每个项目复制一份（推荐，可自定义配置）
cp organize-docs.sh project1/
cp organize-docs.sh project2/

# 方式2：使用符号链接（共享脚本，各自配置）
ln -s /path/to/organize-docs.sh project1/
ln -s /path/to/organize-docs.sh project2/
```

## 兼容性

- 支持 macOS 和 Linux
- 兼容 Bash 3.2+
- 处理文件名中的特殊字符（空格、中文等）

## 故障排除

### 未找到文档文件

- 检查扫描目录是否正确
- 使用 `--verbose` 查看详细日志
- 确认文档扩展名在配置中

### 文件处理失败

- 检查文件权限
- 确认磁盘空间充足
- 查看错误日志（`.organize-docs.log`）

## 许可证

本脚本可自由使用和修改。
