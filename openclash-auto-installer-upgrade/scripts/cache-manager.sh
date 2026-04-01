#!/bin/bash
# 缓存管理工具
# 功能：缓存查看、清理、导入导出、验证

set -Eeuo pipefail

# 导入库
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
source "${LIB_DIR}/error.sh"
source "${LIB_DIR}/cache.sh"

# 设置错误处理
set_error_trap "cache-manager"
setup_error_logging "/tmp/cache-manager.log"

# 显示横幅
show_banner() {
    cat <<'EOF'
╔═══════════════════════════════════════════╗
║      OpenClash 缓存管理工具 v1.0         ║
║           智能网络层增强版               ║
╚═══════════════════════════════════════════╝
EOF
}

# 交互式菜单
interactive_menu() {
    while true; do
        echo ""
        echo "📊 缓存管理菜单"
        echo "═══════════════════════════════════════════"
        echo "1. 查看缓存统计"
        echo "2. 列出缓存内容"
        echo "3. 查找缓存文件"
        echo "4. 清理缓存"
        echo "5. 导出缓存"
        echo "6. 导入缓存"
        echo "7. 验证缓存完整性"
        echo "8. 缓存设置"
        echo "0. 退出"
        echo "═══════════════════════════════════════════"
        
        read -p "请选择 [0-8]: " choice
        
        case "$choice" in
            1)
                echo ""
                cache_stats
                ;;
            2)
                echo ""
                echo "列表格式:"
                echo "  1. 简单列表"
                echo "  2. 详细列表"
                read -p "选择格式 [1-2]: " format_choice
                case "$format_choice" in
                    1) list_cache "simple" ;;
                    2) list_cache "detailed" ;;
                    *) echo "使用简单列表"; list_cache "simple" ;;
                esac
                ;;
            3)
                echo ""
                read -p "输入搜索关键词: " search_term
                find_cache "$search_term"
                ;;
            4)
                echo ""
                echo "清理选项:"
                echo "  1. 清理所有缓存"
                echo "  2. 清理7天前的缓存"
                echo "  3. 清理特定模式缓存"
                echo "  4. 模拟清理（不实际删除）"
                read -p "选择 [1-4]: " clean_choice
                
                case "$clean_choice" in
                    1)
                        confirm_action "确定清理所有缓存吗?" "no" && clean_cache "*"
                        ;;
                    2)
                        confirm_action "确定清理7天前的缓存吗?" "no" && clean_cache "*" 7
                        ;;
                    3)
                        read -p "输入清理模式（如 *.pub）: " pattern
                        confirm_action "确定清理模式 '$pattern' 的缓存吗?" "no" && clean_cache "$pattern"
                        ;;
                    4)
                        echo "模拟清理运行:"
                        clean_cache "*" "" "1"
                        ;;
                    *)
                        echo "取消清理"
                        ;;
                esac
                ;;
            5)
                echo ""
                read -p "导出目录 [默认: ./openclash-cache-export]: " export_dir
                export_dir="${export_dir:-./openclash-cache-export}"
                
                echo "导出选项:"
                echo "  1. 包含元数据"
                echo "  2. 不包含元数据"
                read -p "选择 [1-2]: " meta_choice
                
                case "$meta_choice" in
                    1) export_cache "$export_dir" "1" ;;
                    2) export_cache "$export_dir" "0" ;;
                    *) export_cache "$export_dir" "1" ;;
                esac
                ;;
            6)
                echo ""
                read -p "导入目录 [默认: ./openclash-cache-import]: " import_dir
                import_dir="${import_dir:-./openclash-cache-import}"
                import_cache "$import_dir"
                ;;
            7)
                echo ""
                verify_cache
                ;;
            8)
                echo ""
                echo "📁 缓存设置"
                echo "当前缓存目录: ${CACHE_DIR:-/tmp/openclash-smart-cache}"
                echo ""
                echo "选项:"
                echo "  1. 更改缓存目录"
                echo "  2. 查看缓存目录权限"
                echo "  3. 创建缓存目录"
                echo "  4. 返回"
                read -p "选择 [1-4]: " setting_choice
                
                case "$setting_choice" in
                    1)
                        read -p "新缓存目录: " new_dir
                        if [ -n "$new_dir" ]; then
                            export CACHE_DIR="$new_dir"
                            echo "缓存目录已设置为: $CACHE_DIR"
                        fi
                        ;;
                    2)
                        echo "缓存目录权限:"
                        ls -ld "${CACHE_DIR:-/tmp/openclash-smart-cache}" 2>/dev/null || echo "目录不存在"
                        ;;
                    3)
                        ensure_cache_dir
                        echo "缓存目录已创建"
                        ;;
                esac
                ;;
            0)
                echo ""
                log INFO "退出缓存管理工具"
                exit 0
                ;;
            *)
                echo "无效选择，请重试"
                ;;
        esac
        
        # 暂停以便查看结果
        if [ "$choice" != "0" ]; then
            echo ""
            read -p "按回车键继续..."
        fi
    done
}

# 显示帮助
show_help() {
    cat <<'EOF'
缓存管理工具 v1.0

用法: cache-manager.sh [命令] [选项]

命令:
  stats                  查看缓存统计
  list [格式]           列出缓存内容 (simple|detailed)
  find <关键词>         查找缓存文件
  clean [模式] [天数]   清理缓存
  export [目录]         导出缓存
  import [目录]         导入缓存
  verify                 验证缓存完整性
  menu                   交互式菜单 (默认)
  help                   显示帮助

选项:
  --dry-run             模拟运行（清理时）
  --no-metadata         导出时不包含元数据
  --cache-dir <目录>    指定缓存目录

示例:
  ./cache-manager.sh stats                    # 查看统计
  ./cache-manager.sh list detailed            # 详细列表
  ./cache-manager.sh find "passwall"          # 查找passwall缓存
  ./cache-manager.sh clean "*.pub"            # 清理公钥缓存
  ./cache-manager.sh clean "*" 7 --dry-run    # 模拟清理7天前缓存
  ./cache-manager.sh export ./my-cache        # 导出缓存
  ./cache-manager.sh import ./my-cache        # 导入缓存
  ./cache-manager.sh verify                   # 验证完整性
  ./cache-manager.sh menu                     # 交互式菜单

环境变量:
  CACHE_DIR             缓存目录
  DEBUG=1               调试模式
  FORCE_YES=1           跳过确认

缓存目录结构:
  /tmp/openclash-smart-cache/
  ├── <hash1>            # 缓存文件
  ├── <hash1>.meta       # 元数据文件
  ├── <hash2>
  └── <hash2>.meta

元数据文件包含:
  url=原始URL
  hash=文件哈希
  algo=哈希算法
  timestamp=缓存时间戳
  date=缓存日期
  size=文件大小

EOF
}

# 主函数
main() {
    # 显示横幅
    show_banner
    echo ""
    
    # 如果没有参数，显示交互菜单
    if [ $# -eq 0 ]; then
        interactive_menu
        return 0
    fi
    
    # 解析命令
    local command="$1"
    shift
    
    case "$command" in
        stats|status)
            cache_stats
            ;;
        list|ls)
            local format="${1:-simple}"
            list_cache "$format"
            ;;
        find|search)
            if [ -z "${1:-}" ]; then
                log ERROR "请提供搜索关键词"
                show_help
                return 1
            fi
            find_cache "$1"
            ;;
        clean|clear)
            local pattern="${1:-*}"
            local age_days="${2:-}"
            local dry_run="0"
            
            # 检查额外参数
            for arg in "$@"; do
                if [ "$arg" = "--dry-run" ]; then
                    dry_run="1"
                fi
            done
            
            # 确认（除非FORCE_YES=1）
            if [ "${FORCE_YES:-0}" != "1" ] && [ "$dry_run" != "1" ]; then
                confirm_action "确定清理缓存吗?" "no" || return 0
            fi
            
            clean_cache "$pattern" "$age_days" "$dry_run"
            ;;
        export)
            local output_dir="${1:-./openclash-cache-export}"
            local include_metadata="1"
            
            for arg in "$@"; do
                if [ "$arg" = "--no-metadata" ]; then
                    include_metadata="0"
                fi
            done
            
            export_cache "$output_dir" "$include_metadata"
            ;;
        import)
            local import_dir="${1:-./openclash-cache-import}"
            import_cache "$import_dir"
            ;;
        verify|check)
            verify_cache
            ;;
        menu)
            interactive_menu
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log ERROR "未知命令: $command"
            show_help
            return 1
            ;;
    esac
}

# 运行主函数
main "$@"

# 优雅退出
graceful_exit 0 "缓存管理完成"