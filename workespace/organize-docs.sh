#!/bin/bash

# ============================================================================
# 通用项目文档整理脚本
# 用途：自动识别、分类和整理项目中的各类文档文件
# 支持：Markdown、文本、YAML、JSON、PDF 等多种文档格式
# 作者：自动生成
# 版本：1.0.0
# ============================================================================

set -eo pipefail

# ============================================================================
# 颜色定义
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# 默认配置（内置在脚本中）
# ============================================================================
DOC_EXTENSIONS="md markdown txt rst org pdf docx doc"
CONFIG_DOC_EXTENSIONS="yml yaml json xml"
EXCLUDE_DIRS=".git node_modules .specstory dist build .next .venv venv __pycache__ .cache"
CLASSIFY_MODE="date"
TARGET_DIR="docs"
GENERATE_INDEX=true
FILE_OPERATION="copy"
DRY_RUN=false
INTERACTIVE=false
VERBOSE=false

# ============================================================================
# 全局变量
# ============================================================================
SCRIPT_DIR=""
PROJECT_ROOT=""
CONFIG_FILE=".organize-docs.conf"
SCAN_DIRS=""
OPERATION_LOG=""

# ============================================================================
# 工具函数
# ============================================================================

# 打印信息
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# 显示使用说明
show_usage() {
    cat << EOF
使用方法: $0 [选项]

通用项目文档整理脚本，自动识别、分类和整理项目中的各类文档文件。

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

示例:
  $0 --dry-run                    # 预览整理结果
  $0 --mode type                  # 按类型分类
  $0 --target docs/archive        # 指定目标目录
  $0 --config custom.conf         # 使用自定义配置

EOF
}

# ============================================================================
# 项目根目录检测
# ============================================================================

detect_project_root() {
    local current_dir="$1"
    local check_dir="$current_dir"
    
    # 向上查找，直到找到项目标志或到达用户主目录
    while [ "$check_dir" != "/" ] && [ "$check_dir" != "$HOME" ]; do
        # 检查项目标志
        if [ -d "$check_dir/.git" ] || \
           [ -f "$check_dir/package.json" ] || \
           [ -f "$check_dir/pom.xml" ] || \
           [ -f "$check_dir/Cargo.toml" ] || \
           [ -n "$(find "$check_dir" -maxdepth 1 -name "*.code-workspace" 2>/dev/null)" ]; then
            PROJECT_ROOT="$check_dir"
            debug "检测到项目根目录: $PROJECT_ROOT"
            return 0
        fi
        check_dir="$(dirname "$check_dir")"
    done
    
    # 如果没找到，使用脚本所在目录的父目录
    PROJECT_ROOT="$(dirname "$current_dir")"
    warning "未找到项目标志，使用目录: $PROJECT_ROOT"
    return 0
}

# ============================================================================
# 配置文件加载
# ============================================================================

load_config() {
    local config_path="$1"
    
    if [ ! -f "$config_path" ]; then
        debug "配置文件不存在: $config_path，使用默认配置"
        return 0
    fi
    
    info "加载配置文件: $config_path"
    
    # 安全地加载配置文件
    while IFS= read -r line || [ -n "$line" ]; do
        # 跳过注释和空行
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # 解析配置项
        if [[ "$line" =~ ^[[:space:]]*([A-Z_]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            # 移除引号
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            
            case "$key" in
                DOC_EXTENSIONS)
                    DOC_EXTENSIONS="$value"
                    ;;
                CONFIG_DOC_EXTENSIONS)
                    CONFIG_DOC_EXTENSIONS="$value"
                    ;;
                SCAN_DIRS)
                    SCAN_DIRS="$value"
                    ;;
                EXCLUDE_DIRS)
                    EXCLUDE_DIRS="$value"
                    ;;
                CLASSIFY_MODE)
                    CLASSIFY_MODE="$value"
                    ;;
                TARGET_DIR)
                    TARGET_DIR="$value"
                    ;;
                GENERATE_INDEX)
                    if [[ "$value" =~ ^(true|yes|1)$ ]]; then
                        GENERATE_INDEX=true
                    else
                        GENERATE_INDEX=false
                    fi
                    ;;
                FILE_OPERATION)
                    FILE_OPERATION="$value"
                    ;;
            esac
        fi
    done < "$config_path"
}

# ============================================================================
# 命令行参数解析
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --target)
                TARGET_DIR="$2"
                shift 2
                ;;
            --mode)
                CLASSIFY_MODE="$2"
                shift 2
                ;;
            --scan)
                SCAN_DIRS="$2"
                shift 2
                ;;
            --exclude)
                EXCLUDE_DIRS="$2"
                shift 2
                ;;
            --operation)
                FILE_OPERATION="$2"
                shift 2
                ;;
            --no-index)
                GENERATE_INDEX=false
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# 文档类型判断
# ============================================================================

is_document_file() {
    local file="$1"
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    # 检查文档扩展名
    for doc_ext in $DOC_EXTENSIONS $CONFIG_DOC_EXTENSIONS; do
        if [ "$ext" = "$doc_ext" ]; then
            return 0
        fi
    done
    
    # 检查项目文档文件名
    local basename=$(basename "$file")
    if [[ "$basename" =~ ^(README|CHANGELOG|LICENSE|CONTRIBUTING|AUTHORS) ]]; then
        return 0
    fi
    
    return 1
}

# ============================================================================
# 目录排除判断
# ============================================================================

should_exclude() {
    local dir_path="$1"
    local dir_name=$(basename "$dir_path")
    
    for exclude_dir in $EXCLUDE_DIRS; do
        if [ "$dir_name" = "$exclude_dir" ]; then
            return 0
        fi
    done
    
    return 1
}

# ============================================================================
# 文档扫描
# ============================================================================

find_documents() {
    local scan_dirs="$1"
    local documents=()
    
    # 如果没有指定扫描目录，自动检测
    if [ -z "$scan_dirs" ]; then
        scan_dirs=""
        # 检查常见目录
        [ -d "$PROJECT_ROOT/.specstory/history" ] && scan_dirs="$scan_dirs $PROJECT_ROOT/.specstory/history"
        [ -d "$PROJECT_ROOT/docs" ] && scan_dirs="$scan_dirs $PROJECT_ROOT/docs"
        [ -d "$PROJECT_ROOT/guide" ] && scan_dirs="$scan_dirs $PROJECT_ROOT/guide"
        # 添加项目根目录（用于 README 等文件）
        scan_dirs="$scan_dirs $PROJECT_ROOT"
    else
        # 将相对路径转换为绝对路径
        local abs_dirs=""
        for dir in $scan_dirs; do
            if [[ "$dir" = /* ]]; then
                abs_dirs="$abs_dirs $dir"
            else
                abs_dirs="$abs_dirs $PROJECT_ROOT/$dir"
            fi
        done
        scan_dirs="$abs_dirs"
    fi
    
    debug "扫描目录: $scan_dirs"
    
    # 构建 find 排除选项
    local exclude_opts=""
    for exclude_dir in $EXCLUDE_DIRS; do
        exclude_opts="$exclude_opts -name $exclude_dir -prune -o"
    done
    
    # 查找文档文件
    while IFS= read -r -d '' file; do
        if is_document_file "$file"; then
            # 检查文件是否在排除目录中
            local file_dir=$(dirname "$file")
            local should_skip=false
            
            for exclude_dir in $EXCLUDE_DIRS; do
                if [[ "$file_dir" == *"/$exclude_dir"* ]] || [[ "$file_dir" == *"/$exclude_dir/"* ]]; then
                    should_skip=true
                    break
                fi
            done
            
            if [ "$should_skip" = false ]; then
                documents+=("$file")
            fi
        fi
    done < <(find $scan_dirs -type f -print0 2>/dev/null || true)
    
    printf '%s\n' "${documents[@]}"
}

# ============================================================================
# 日期提取
# ============================================================================

extract_date() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    
    # 尝试从文件名提取日期（YYYY-MM-DD, YYYY_MM_DD, YYYYMMDD）
    local date_patterns=(
        "([0-9]{4})-([0-9]{2})-([0-9]{2})"
        "([0-9]{4})_([0-9]{2})_([0-9]{2})"
        "([0-9]{4})([0-9]{2})([0-9]{2})"
    )
    
    for pattern in "${date_patterns[@]}"; do
        if [[ "$filename" =~ $pattern ]]; then
            local year="${BASH_REMATCH[1]}"
            local month="${BASH_REMATCH[2]}"
            local day="${BASH_REMATCH[3]}"
            echo "${year}-${month}-${day}"
            return 0
        fi
    done
    
    # 备选：使用文件修改时间
    local mod_time=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        mod_time=$(stat -f "%Sm" -t "%Y-%m-%d" "$file_path" 2>/dev/null || echo "")
    else
        # Linux
        mod_time=$(stat -c "%y" "$file_path" 2>/dev/null | cut -d' ' -f1 || echo "")
    fi
    
    if [ -n "$mod_time" ]; then
        echo "$mod_time"
        return 0
    fi
    
    # 最后备选：使用当前日期
    date +"%Y-%m-%d"
}

# ============================================================================
# 项目标识识别
# ============================================================================

extract_project_id() {
    local file_path="$1"
    
    # 方法1: 从 workspace 文件名提取
    for workspace_file in "$PROJECT_ROOT"/*.code-workspace; do
        if [ -f "$workspace_file" ]; then
            local ws_name=$(basename "$workspace_file" .code-workspace)
            # 清理名称（移除数字前缀、特殊字符）
            ws_name=$(echo "$ws_name" | sed 's/^[0-9]*//' | sed 's/[^a-zA-Z0-9]//g')
            if [ -n "$ws_name" ]; then
                echo "$ws_name"
                return 0
            fi
        fi
    done
    
    # 方法2: 从 package.json 提取
    if [ -f "$PROJECT_ROOT/package.json" ]; then
        local pkg_name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_ROOT/package.json" 2>/dev/null | head -1 | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        if [ -n "$pkg_name" ]; then
            echo "$pkg_name"
            return 0
        fi
    fi
    
    # 方法3: 从文件路径提取
    local path_part=$(echo "$file_path" | grep -o '[^/]*/' | head -1 | sed 's/\///')
    if [ -n "$path_part" ] && [ "$path_part" != "." ]; then
        echo "$path_part"
        return 0
    fi
    
    # 方法4: 使用项目根目录名
    echo "$(basename "$PROJECT_ROOT")"
}

# ============================================================================
# 文档类型识别
# ============================================================================

classify_document_type() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    local ext="${file_path##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    # 根据扩展名分类
    case "$ext" in
        yml|yaml|json|xml)
            echo "config"
            ;;
        md|markdown|txt|rst|org)
            # 根据文件名关键词分类
            if [[ "$filename" =~ (分析|analysis|analyze) ]]; then
                echo "analysis"
            elif [[ "$filename" =~ (设计|design|架构|architecture) ]]; then
                echo "design"
            elif [[ "$filename" =~ (指南|guide|教程|tutorial) ]]; then
                echo "guide"
            elif [[ "$filename" =~ (配置|config|设置|setting) ]]; then
                echo "config"
            else
                echo "general"
            fi
            ;;
        pdf|docx|doc)
            echo "document"
            ;;
        *)
            echo "general"
            ;;
    esac
}

# ============================================================================
# 文件名规范化
# ============================================================================

normalize_filename() {
    local file_path="$1"
    local date="$2"
    local project_id="$3"
    local doc_type="$4"
    
    local filename=$(basename "$file_path")
    local ext="${filename##*.}"
    
    # 移除已有的日期前缀
    filename=$(echo "$filename" | sed -E 's/^[0-9]{4}[_-]?[0-9]{2}[_-]?[0-9]{2}[_-]?//')
    
    # 移除项目标识前缀
    if [ -n "$project_id" ]; then
        filename=$(echo "$filename" | sed "s/^${project_id}[_-]//i")
    fi
    
    # 构建新文件名
    local new_name="${date}"
    if [ -n "$project_id" ] && [ "$project_id" != "general" ]; then
        new_name="${new_name}_${project_id}"
    fi
    if [ -n "$doc_type" ] && [ "$doc_type" != "general" ]; then
        new_name="${new_name}_${doc_type}"
    fi
    new_name="${new_name}_${filename}"
    
    echo "$new_name"
}

# ============================================================================
# 冲突处理
# ============================================================================

handle_conflict() {
    local target_path="$1"
    local counter=1
    
    while [ -e "$target_path" ]; do
        local dir=$(dirname "$target_path")
        local filename=$(basename "$target_path")
        local ext="${filename##*.}"
        local name="${filename%.*}"
        
        target_path="${dir}/${name}_${counter}.${ext}"
        counter=$((counter + 1))
    done
    
    echo "$target_path"
}

# ============================================================================
# 文件操作
# ============================================================================

move_or_copy() {
    local source="$1"
    local target="$2"
    
    # 确保目标目录存在
    local target_dir=$(dirname "$target")
    mkdir -p "$target_dir"
    
    if [ "$DRY_RUN" = true ]; then
        info "  [预览] $source -> $target"
        return 0
    fi
    
    # 交互式确认
    if [ "$INTERACTIVE" = true ]; then
        echo -n "移动文件 $source 到 $target? (y/n): "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # 执行操作
    if [ "$FILE_OPERATION" = "move" ]; then
        mv "$source" "$target" 2>/dev/null || cp "$source" "$target"
        success "  移动: $source -> $target"
    else
        cp "$source" "$target"
        success "  复制: $source -> $target"
    fi
    
    # 记录操作日志
    echo "$source|$target|$FILE_OPERATION" >> "$OPERATION_LOG"
    
    return 0
}

# ============================================================================
# 分类逻辑
# ============================================================================

classify_by_date() {
    local file_path="$1"
    local date="$2"
    local project_id="$3"
    local doc_type="$4"
    
    local year=$(echo "$date" | cut -d'-' -f1)
    local month=$(echo "$date" | cut -d'-' -f2)
    
    local target_path="$TARGET_DIR/$year/$month/$(normalize_filename "$file_path" "$date" "$project_id" "$doc_type")"
    target_path=$(handle_conflict "$target_path")
    
    echo "$target_path"
}

classify_by_type() {
    local file_path="$1"
    local date="$2"
    local project_id="$3"
    local doc_type="$4"
    
    local target_path="$TARGET_DIR/$doc_type/$(normalize_filename "$file_path" "$date" "$project_id" "$doc_type")"
    target_path=$(handle_conflict "$target_path")
    
    echo "$target_path"
}

classify_by_project() {
    local file_path="$1"
    local date="$2"
    local project_id="$3"
    local doc_type="$4"
    
    local year=$(echo "$date" | cut -d'-' -f1)
    local month=$(echo "$date" | cut -d'-' -f2)
    
    local target_path="$TARGET_DIR/$project_id/$year/$month/$(normalize_filename "$file_path" "$date" "$project_id" "$doc_type")"
    target_path=$(handle_conflict "$target_path")
    
    echo "$target_path"
}

# ============================================================================
# 索引生成
# ============================================================================

generate_index() {
    if [ "$GENERATE_INDEX" != true ]; then
        return 0
    fi
    
    info "生成索引文件..."
    
    local index_file="$PROJECT_ROOT/$TARGET_DIR/README.md"
    mkdir -p "$(dirname "$index_file")"
    
    cat > "$index_file" << EOF
# 项目文档索引

> 本文档由 organize-docs.sh 自动生成

## 文档统计

- 总文档数: $(find "$PROJECT_ROOT/$TARGET_DIR" -type f ! -name "README.md" ! -name "index.json" 2>/dev/null | wc -l | tr -d ' ')

## 文档列表

EOF
    
    # 根据分类模式生成不同的索引
    case "$CLASSIFY_MODE" in
        date)
            # 按日期分类
            local current_year=""
            local current_month=""
            find "$PROJECT_ROOT/$TARGET_DIR" -type f ! -name "README.md" ! -name "index.json" 2>/dev/null | sort | while read -r file; do
                local rel_path="${file#$PROJECT_ROOT/$TARGET_DIR/}"
                local year=$(echo "$rel_path" | cut -d'/' -f1)
                local month=$(echo "$rel_path" | cut -d'/' -f2)
                local filename=$(basename "$file")
                
                if [ "$year" != "$current_year" ]; then
                    echo "" >> "$index_file"
                    echo "### $year" >> "$index_file"
                    current_year="$year"
                    current_month=""
                fi
                
                if [ "$month" != "$current_month" ]; then
                    echo "" >> "$index_file"
                    echo "#### $year-$month" >> "$index_file"
                    current_month="$month"
                fi
                
                echo "- [$filename](./$rel_path)" >> "$index_file"
            done
            ;;
        type)
            # 按类型分类
            for type_dir in "$PROJECT_ROOT/$TARGET_DIR"/*; do
                if [ -d "$type_dir" ]; then
                    local type_name=$(basename "$type_dir")
                    echo "" >> "$index_file"
                    echo "### $type_name" >> "$index_file"
                    find "$type_dir" -type f 2>/dev/null | sort | while read -r file; do
                        local rel_path="${file#$PROJECT_ROOT/$TARGET_DIR/}"
                        local filename=$(basename "$file")
                        echo "- [$filename](./$rel_path)" >> "$index_file"
                    done
                fi
            done
            ;;
        project)
            # 按项目分类
            for project_dir in "$PROJECT_ROOT/$TARGET_DIR"/*; do
                if [ -d "$project_dir" ]; then
                    local project_name=$(basename "$project_dir")
                    echo "" >> "$index_file"
                    echo "### $project_name" >> "$index_file"
                    find "$project_dir" -type f 2>/dev/null | sort | while read -r file; do
                        local rel_path="${file#$PROJECT_ROOT/$TARGET_DIR/}"
                        local filename=$(basename "$file")
                        echo "- [$filename](./$rel_path)" >> "$index_file"
                    done
                fi
            done
            ;;
    esac
    
    echo "" >> "$index_file"
    echo "---" >> "$index_file"
    echo "*最后更新: $(date '+%Y-%m-%d %H:%M:%S')*" >> "$index_file"
    
    success "索引文件已生成: $index_file"
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 解析命令行参数
    parse_args "$@"
    
    # 检测项目根目录
    detect_project_root "$SCRIPT_DIR"
    info "项目根目录: $PROJECT_ROOT"
    
    # 加载配置文件
    local config_path="$PROJECT_ROOT/$CONFIG_FILE"
    load_config "$config_path"
    
    # 设置操作日志
    OPERATION_LOG="$PROJECT_ROOT/.organize-docs.log"
    > "$OPERATION_LOG"
    
    # 显示配置信息
    info "配置信息:"
    echo "  分类模式: $CLASSIFY_MODE"
    echo "  目标目录: $TARGET_DIR"
    echo "  文件操作: $FILE_OPERATION"
    echo "  生成索引: $GENERATE_INDEX"
    [ "$DRY_RUN" = true ] && warning "  预览模式: 启用"
    
    # 扫描文档
    info "扫描文档文件..."
    local documents=()
    local doc_count=0
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            documents+=("$line")
            doc_count=$((doc_count + 1))
        fi
    done < <(find_documents "$SCAN_DIRS")
    
    if [ $doc_count -eq 0 ]; then
        warning "未找到文档文件"
        exit 0
    fi
    
    info "找到 $doc_count 个文档文件"
    
    # 处理每个文档
    local processed=0
    local skipped=0
    
    for file_path in "${documents[@]}"; do
        # 跳过目标目录中的文件（避免重复处理）
        if [[ "$file_path" == "$PROJECT_ROOT/$TARGET_DIR"* ]]; then
            debug "跳过目标目录中的文件: $file_path"
            continue
        fi
        
        # 提取信息
        local date=$(extract_date "$file_path")
        local project_id=$(extract_project_id "$file_path")
        local doc_type=$(classify_document_type "$file_path")
        
        debug "处理文件: $file_path"
        debug "  日期: $date, 项目: $project_id, 类型: $doc_type"
        
        # 分类
        local target_path=""
        case "$CLASSIFY_MODE" in
            date)
                target_path=$(classify_by_date "$file_path" "$date" "$project_id" "$doc_type")
                ;;
            type)
                target_path=$(classify_by_type "$file_path" "$date" "$project_id" "$doc_type")
                ;;
            project)
                target_path=$(classify_by_project "$file_path" "$date" "$project_id" "$doc_type")
                ;;
            *)
                error "未知的分类模式: $CLASSIFY_MODE"
                exit 1
                ;;
        esac
        
        # 转换为绝对路径
        if [[ "$target_path" != /* ]]; then
            target_path="$PROJECT_ROOT/$target_path"
        fi
        
        # 执行操作
        if move_or_copy "$file_path" "$target_path"; then
            processed=$((processed + 1))
        else
            skipped=$((skipped + 1))
        fi
    done
    
    # 生成索引
    if [ "$processed" -gt 0 ] || [ "$DRY_RUN" = true ]; then
        generate_index
    fi
    
    # 显示统计
    echo ""
    success "整理完成!"
    echo "  处理: $processed 个文件"
    echo "  跳过: $skipped 个文件"
    
    if [ "$DRY_RUN" = true ]; then
        warning "这是预览模式，未实际移动文件"
        echo "运行不带 --dry-run 选项的命令以执行实际整理"
    fi
}

# 执行主函数
main "$@"
