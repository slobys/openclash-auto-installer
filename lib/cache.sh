#!/bin/bash
# 缓存管理工具 v1.0
# 功能：缓存查看、清理、统计、导入导出

set -Eeuo pipefail

# 导入下载库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/download.sh" 2>/dev/null || true

# 颜色输出
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    BOLD='\033[1m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; NC=''; BOLD=''
fi

# 日志函数
log_info() { printf "%b==>%b %s\n" "${BLUE}" "${NC}" "$*" >&2; }
log_success() { printf "%b✅%b %s\n" "${GREEN}" "${NC}" "$*" >&2; }
log_warn() { printf "%b⚠️ %b %s\n" "${YELLOW}" "${NC}" "$*" >&2; }
log_error() { printf "%b❌%b %s\n" "${RED}" "${NC}" "$*" >&2; }

# 默认缓存目录
DEFAULT_CACHE_DIR="/tmp/openclash-smart-cache"
CACHE_DIR="${CACHE_DIR:-$DEFAULT_CACHE_DIR}"

# 确保缓存目录存在
ensure_cache_dir() {
    if [ ! -d "$CACHE_DIR" ]; then
        mkdir -p "$CACHE_DIR"
        log_info "创建缓存目录: $CACHE_DIR"
    fi
}

# 显示缓存统计
cache_stats() {
    ensure_cache_dir
    
    local total_files=0
    local total_size=0
    local cached_urls=0
    
    # 统计文件
    if [ -d "$CACHE_DIR" ]; then
        total_files=$(find "$CACHE_DIR" -type f -name "*.meta" 2>/dev/null | wc -l)
        
        # 计算总大小
        for meta_file in "$CACHE_DIR"/*.meta 2>/dev/null; do
            if [ -f "$meta_file" ]; then
                cached_urls=$((cached_urls + 1))
                local size_line=$(grep '^size=' "$meta_file" 2>/dev/null | cut -d'=' -f2)
                if [[ "$size_line" =~ ^[0-9]+$ ]]; then
                    total_size=$((total_size + size_line))
                fi
            fi
        done
    fi
    
    # 显示统计信息
    cat <<EOF
${BOLD}📊 缓存统计${NC}
├─ 缓存目录: ${CACHE_DIR}
├─ 缓存项目: ${cached_urls} 个
├─ 总文件数: ${total_files} 个
└─ 占用空间: $(format_bytes $total_size)

${BOLD}📁 目录内容${NC}
EOF
    
    # 显示目录内容
    if [ "$(ls -A "$CACHE_DIR" 2>/dev/null | wc -l)" -eq 0 ]; then
        echo "  缓存目录为空"
    else
        ls -lh "$CACHE_DIR" | head -20
        if [ "$(ls -A "$CACHE_DIR" 2>/dev/null | wc -l)" -gt 20 ]; then
            echo "  ... (更多文件，使用 --list 查看全部)"
        fi
    fi
}

# 格式化字节数
format_bytes() {
    local bytes="$1"
    
    if [ "$bytes" -ge 1073741824 ]; then
        printf "%.2f GB" $(echo "$bytes / 1073741824" | bc -l)
    elif [ "$bytes" -ge 1048576 ]; then
        printf "%.2f MB" $(echo "$bytes / 1048576" | bc -l)
    elif [ "$bytes" -ge 1024 ]; then
        printf "%.2f KB" $(echo "$bytes / 1024" | bc -l)
    else
        printf "%d B" "$bytes"
    fi
}

# 列出缓存内容
list_cache() {
    ensure_cache_dir
    
    local format="${1:-simple}"
    
    if [ "$format" = "simple" ]; then
        log_info "缓存内容列表:"
        
        local count=0
        for meta_file in "$CACHE_DIR"/*.meta 2>/dev/null; do
            if [ -f "$meta_file" ]; then
                count=$((count + 1))
                local url=$(grep '^url=' "$meta_file" 2>/dev/null | cut -d'=' -f2-)
                local hash=$(grep '^hash=' "$meta_file" 2>/dev/null | cut -d'=' -f2-)
                local size=$(grep '^size=' "$meta_file" 2>/dev/null | cut -d'=' -f2)
                local date=$(grep '^date=' "$meta_file" 2>/dev/null | cut -d'=' -f2-)
                
                echo "  ${count}. ${url##*/}"
                echo "     大小: ${size:-unknown} | 日期: ${date:-unknown}"
                echo "     哈希: ${hash:0:16}..."
                echo ""
            fi
        done
        
        if [ "$count" -eq 0 ]; then
            echo "  无缓存内容"
        fi
        
    elif [ "$format" = "detailed" ]; then
        log_info "详细缓存列表:"
        
        for meta_file in "$CACHE_DIR"/*.meta 2>/dev/null; do
            if [ -f "$meta_file" ]; then
                echo "=== $(basename "$meta_file" .meta) ==="
                cat "$meta_file"
                echo ""
                
                # 显示关联的缓存文件
                local cache_file="${meta_file%.meta}"
                if [ -f "$cache_file" ]; then
                    echo "缓存文件: $cache_file"
                    file "$cache_file" 2>/dev/null || echo "类型: 未知"
                    echo ""
                fi
            fi
        done
    fi
    
    # 显示缓存文件（非.meta）
    local other_files=$(find "$CACHE_DIR" -type f ! -name "*.meta" 2>/dev/null | wc -l)
    if [ "$other_files" -gt 0 ]; then
        log_warn "发现 $other_files 个未关联的缓存文件"
    fi
}

# 查找特定URL的缓存
find_cache() {
    local search_term="$1"
    
    ensure_cache_dir
    
    local found=0
    for meta_file in "$CACHE_DIR"/*.meta 2>/dev/null; do
        if [ -f "$meta_file" ]; then
            local url=$(grep '^url=' "$meta_file" 2>/dev/null | cut -d'=' -f2-)
            
            if echo "$url" | grep -iq "$search_term"; then
                found=$((found + 1))
                echo "匹配 $found:"
                echo "  URL: $url"
                
                local cache_file="${meta_file%.meta}"
                if [ -f "$cache_file" ]; then
                    local size=$(stat -c%s "$cache_file" 2>/dev/null || stat -f%z "$cache_file" 2>/dev/null || echo "unknown")
                    echo "  文件: $(basename "$cache_file") ($(format_bytes "$size"))"
                    echo "  路径: $cache_file"
                fi
                
                # 显示元数据
                grep -E '^(hash=|algo=|date=)' "$meta_file" 2>/dev/null || true
                echo ""
            fi
        fi
    done
    
    if [ "$found" -eq 0 ]; then
        log_warn "未找到匹配 '$search_term' 的缓存"
        return 1
    fi
    
    log_info "找到 $found 个匹配项"
}

# 清理缓存
clean_cache() {
    local pattern="${1:-*}"
    local age_days="${2:-}"
    local dry_run="${3:-}"
    
    ensure_cache_dir
    
    local deleted_files=0
    local deleted_size=0
    
    log_info "清理缓存: pattern='$pattern'${age_days:+ age>${age_days}d}${dry_run:+ (模拟运行)}"
    
    for meta_file in "$CACHE_DIR"/$pattern.meta 2>/dev/null; do
        if [ -f "$meta_file" ]; then
            local should_delete=1
            
            # 检查文件年龄
            if [ -n "$age_days" ]; then
                local file_age=$(($(date +%s) - $(stat -c%Y "$meta_file" 2>/dev/null || echo 0)))
                local max_age=$((age_days * 86400))
                
                if [ "$file_age" -le "$max_age" ]; then
                    should_delete=0
                fi
            fi
            
            if [ "$should_delete" -eq 1 ]; then
                local cache_file="${meta_file%.meta}"
                local file_size=0
                
                # 计算文件大小
                if [ -f "$cache_file" ]; then
                    file_size=$(stat -c%s "$cache_file" 2>/dev/null || stat -f%z "$cache_file" 2>/dev/null || echo 0)
                fi
                
                if [ "$dry_run" = "1" ]; then
                    local url=$(grep '^url=' "$meta_file" 2>/dev/null | cut -d'=' -f2-)
                    echo "[模拟] 删除: ${url##*/} ($(format_bytes "$file_size"))"
                else
                    rm -f "$cache_file" "$meta_file"
                fi
                
                deleted_files=$((deleted_files + 1))
                deleted_size=$((deleted_size + file_size))
            fi
        fi
    done
    
    # 清理孤儿文件（没有.meta的缓存文件）
    for cache_file in "$CACHE_DIR"/$pattern 2>/dev/null; do
        if [ -f "$cache_file" ] && [[ "$cache_file" != *.meta ]]; then
            local meta_file="${cache_file}.meta"
            if [ ! -f "$meta_file" ]; then
                local file_size=$(stat -c%s "$cache_file" 2>/dev/null || stat -f%z "$cache_file" 2>/dev/null || echo 0)
                
                if [ "$dry_run" = "1" ]; then
                    echo "[模拟] 删除孤儿文件: $(basename "$cache_file") ($(format_bytes "$file_size"))"
                else
                    rm -f "$cache_file"
                fi
                
                deleted_files=$((deleted_files + 1))
                deleted_size=$((deleted_size + file_size))
            fi
        fi
    done
    
    if [ "$dry_run" = "1" ]; then
        log_info "模拟运行完成: 将删除 $deleted_files 个文件 ($(format_bytes $deleted_size))"
    else
        log_success "清理完成: 删除 $deleted_files 个文件 ($(format_bytes $deleted_size))"
    fi
}

# 导出缓存
export_cache() {
    local output_dir="${1:-./openclash-cache-export}"
    local include_metadata="${2:-1}"
    
    ensure_cache_dir
    
    log_info "导出缓存到: $output_dir"
    
    mkdir -p "$output_dir"
    
    local exported=0
    for meta_file in "$CACHE_DIR"/*.meta 2>/dev/null; do
        if [ -f "$meta_file" ]; then
            local cache_file="${meta_file%.meta}"
            if [ -f "$cache_file" ]; then
                # 生成友好文件名
                local url=$(grep '^url=' "$meta_file" 2>/dev/null | cut -d'=' -f2-)
                local filename=$(basename "$url")
                if [ -z "$filename" ] || [ "$filename" = "/" ]; then
                    filename="cached_file_$(basename "$cache_file")"
                fi
                
                # 复制文件
                cp -f "$cache_file" "$output_dir/$filename"
                
                # 复制元数据
                if [ "$include_metadata" = "1" ]; then
                    cp -f "$meta_file" "$output_dir/${filename}.meta"
                fi
                
                exported=$((exported + 1))
            fi
        fi
    done
    
    # 创建索引文件
    if [ "$exported" -gt 0 ]; then
        cat > "$output_dir/INDEX.txt" <<EOF
OpenClash 缓存导出
导出时间: $(date)
来源目录: $CACHE_DIR
文件数量: $exported

包含文件:
$(cd "$output_dir" && find . -type f ! -name "INDEX.txt" | sort)
EOF
        
        log_success "导出完成: $exported 个文件"
        echo "导出位置: $output_dir"
        echo "索引文件: $output_dir/INDEX.txt"
    else
        log_warn "没有可导出的缓存文件"
        rmdir "$output_dir" 2>/dev/null || true
    fi
}

# 导入缓存
import_cache() {
    local import_dir="${1:-./openclash-cache-import}"
    
    if [ ! -d "$import_dir" ]; then
        log_error "导入目录不存在: $import_dir"
        return 1
    fi
    
    ensure_cache_dir
    
    log_info "从目录导入缓存: $import_dir"
    
    local imported=0
    local skipped=0
    
    # 导入.meta文件
    for meta_file in "$import_dir"/*.meta 2>/dev/null; do
        if [ -f "$meta_file" ]; then
            local cache_file="${meta_file%.meta}"
            local target_meta="$CACHE_DIR/$(basename "$meta_file")"
            local target_cache="$CACHE_DIR/$(basename "$cache_file")"
            
            # 检查是否已存在
            if [ ! -f "$target_meta" ] || [ ! -f "$target_cache" ]; then
                cp -f "$meta_file" "$target_meta"
                if [ -f "$cache_file" ]; then
                    cp -f "$cache_file" "$target_cache"
                fi
                imported=$((imported + 1))
            else
                skipped=$((skipped + 1))
            fi
        fi
    done
    
    # 导入没有.meta的缓存文件（通过URL推断）
    for cache_file in "$import_dir"/* 2>/dev/null; do
        if [ -f "$cache_file" ] && [[ "$cache_file" != *.meta ]] && [[ "$(basename "$cache_file")" != "INDEX.txt" ]]; then
            local filename=$(basename "$cache_file")
            local meta_file="$cache_file.meta"
            
            # 如果对应.meta文件不存在，创建一个基本元数据
            if [ ! -f "$meta_file" ]; then
                local target_meta="$CACHE_DIR/${filename}.meta"
                if [ ! -f "$target_meta" ]; then
                    cat > "$target_meta" <<EOF
url=imported://$filename
hash=$(file_hash "$cache_file" sha256 2>/dev/null || echo unknown)
algo=sha256
timestamp=$(date +%s)
date=$(date -Iseconds)
size=$(stat -c%s "$cache_file" 2>/dev/null || stat -f%z "$cache_file" 2>/dev/null || echo unknown)
EOF
                    cp -f "$cache_file" "$CACHE_DIR/$filename"
                    imported=$((imported + 1))
                else
                    skipped=$((skipped + 1))
                fi
            fi
        fi
    done
    
    log_success "导入完成: $imported 个新文件, $skipped 个已跳过"
}

# 验证缓存完整性
verify_cache() {
    ensure_cache_dir
    
    log_info "验证缓存完整性..."
    
    local valid=0
    local invalid=0
    local total=0
    
    for meta_file in "$CACHE_DIR"/*.meta 2>/dev/null; do
        if [ -f "$meta_file" ]; then
            total=$((total + 1))
            local cache_file="${meta_file%.meta}"
            
            if [ ! -f "$cache_file" ]; then
                log_warn "缓存文件缺失: $(basename "$cache_file")"
                rm -f "$meta_file"
                invalid=$((invalid + 1))
                continue
            fi
            
            # 验证哈希
            local expected_hash=$(grep '^hash=' "$meta_file" 2>/dev/null | cut -d'=' -f2)
            local expected_algo=$(grep '^algo=' "$meta_file" 2>/dev/null | cut -d'=' -f2)
            
            if [ -n "$expected_hash" ] && [ -n "$expected_algo" ]; then
                local actual_hash=$(file_hash "$cache_file" "$expected_algo" 2>/dev/null)
                
                if [ "$actual_hash" = "$expected_hash" ]; then
                    valid=$((valid + 1))
                else
                    log_warn "哈希不匹配: $(basename "$cache_file")"
                    log_warn "  期望: ${expected_hash:0:16}..."
                    log_warn "  实际: ${actual_hash:0:16}..."
                    invalid=$((invalid + 1))
                fi
            else
                log_warn "元数据不完整: $(basename "$meta_file")"
                valid=$((valid + 1)) # 没有哈希信息，假设有效
            fi
        fi
    done
    
    # 检查孤儿文件
    local orphan_files=0
    for cache_file in "$CACHE_DIR"/* 2>/dev/null; do
        if [ -f "$cache_file" ] && [[ "$cache_file" != *.meta ]]; then
            local meta_file="${cache_file}.meta"
            if [ ! -f "$meta_file" ]; then
                orphan_files=$((orphan_files + 1))
            fi
        fi
    done
    
    # 输出结果
    cat <<EOF
${BOLD}📋 缓存验证结果${NC}
├─ 总缓存项目: $total
├─ 有效项目: $valid
├─ 无效项目: $invalid
├─ 孤儿文件: $orphan_files
└─ 整体完整性: $((total > 0 ? (valid * 100 / total) : 100))%

EOF
    
    if [ "$invalid" -gt 0 ] || [ "$orphan_files" -gt 0 ]; then
        log_warn "发现缓存问题，建议运行: $0 --clean"
        return 1
    fi
    
    log_success "缓存完整性良好"
    return 0
}

# 显示帮助
show_help() {
    cat <<EOF
缓存管理工具 v1.0
用法: $0 <命令> [选项]

命令:
  stats                  显示缓存统计信息
  list [simple|detailed] 列出缓存内容
  find <关键词>          查找特定缓存
  clean [模式] [天数]    清理缓存（支持通配符）
  export [目录]          导出缓存到目录
  import [目录]          从目录导入缓存
  verify                 验证缓存完整性
  help                   显示帮助

选项:
  --dry-run              模拟运行（不实际删除）
  --no-metadata          导出时不包含元数据
  --age-days <天数>      清理指定天数前的缓存

环境变量:
  CACHE_DIR              缓存目录（默认: /tmp/openclash-smart-cache）

示例:
  $0 stats                    # 显示统计
  $0 list detailed            # 详细列表
  $0 find "passwall"          # 查找passwall相关缓存
  $0 clean "*.pub"            # 清理所有公钥缓存
  $0 clean "*" 7              # 清理7天前的所有缓存
  $0 clean "*" 7 --dry-run    # 模拟清理
  $0 export ./my-cache        # 导出缓存
  $0 import ./my-cache        # 导入缓存
  $0 verify                   # 验证完整性

EOF
}

# 主函数
main() {
    local command="${1:-stats}"
    
    case "$command" in
        stats|status)
            cache_stats
            ;;
        list|ls)
            local format="${2:-simple}"
            list_cache "$format"
            ;;
        find|search)
            if [ -z "${2:-}" ]; then
                log_error "请提供搜索关键词"
                show_help
                return 1
            fi
            find_cache "$2"
            ;;
        clean|clear)
            local pattern="${2:-*}"
            local age_days="${3:-}"
            local dry_run="0"
            
            # 检查是否有--dry-run参数
            for arg in "$@"; do
                if [ "$arg" = "--dry-run" ]; then
                    dry_run="1"
                elif [[ "$arg" =~ ^--age-days=([0-9]+)$ ]]; then
                    age_days="${BASH_REMATCH[1]}"
                elif [[ "$arg" =~ ^[0-9]+$ ]] && [ -z "$age_days" ] && [ "$arg" != "$pattern" ]; then
                    age_days="$arg"
                fi
            done
            
            clean_cache "$pattern" "$age_days" "$dry_run"
            ;;
        export)
            local output_dir="${2:-./openclash-cache-export}"
            local include_metadata="1"
            
            for arg in "$@"; do
                if [ "$arg" = "--no-metadata" ]; then
                    include_metadata="0"
                fi
            done
            
            export_cache "$output_dir" "$include_metadata"
            ;;
        import)
            local import_dir="${2:-./openclash-cache-import}"
            import_cache "$import_dir"
            ;;
        verify|check)
            verify_cache
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            return 1
            ;;
    esac
}

# 如果直接运行
if [ "$(basename "$0")" = "cache.sh" ]; then
    main "$@"
fi