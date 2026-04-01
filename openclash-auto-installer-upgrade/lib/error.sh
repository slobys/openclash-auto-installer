#!/bin/bash
# 错误处理与恢复指南 v1.0
# 功能：统一错误处理、友好错误信息、恢复建议、日志记录

set -Eeuo pipefail

# 导入颜色支持
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

# 日志级别
LOG_LEVEL="${LOG_LEVEL:-INFO}" # DEBUG, INFO, WARN, ERROR

# 日志函数
log() {
    local level="$1"
    local message="$2"
    local color=""
    local prefix=""
    
    # 检查日志级别
    case "$LOG_LEVEL" in
        DEBUG) level_num=0 ;;
        INFO)  level_num=1 ;;
        WARN)  level_num=2 ;;
        ERROR) level_num=3 ;;
        *)     level_num=1 ;;
    esac
    
    case "$level" in
        DEBUG) [ $level_num -le 0 ] || return 0; color="$MAGENTA"; prefix="[DEBUG]" ;;
        INFO)  [ $level_num -le 1 ] || return 0; color="$BLUE"; prefix="==>" ;;
        WARN)  [ $level_num -le 2 ] || return 0; color="$YELLOW"; prefix="⚠️ " ;;
        ERROR) [ $level_num -le 3 ] || return 0; color="$RED"; prefix="❌" ;;
        *)     color="$NC"; prefix="[*]" ;;
    esac
    
    printf "%b%s%b %s\n" "$color" "$prefix" "$NC" "$message" >&2
}

# 设置错误陷阱
set_error_trap() {
    local script_name="${1:-$(basename "$0")}"
    
    trap 'error_handler "$script_name" $? "$LINENO" "$BASH_COMMAND"' ERR
    trap 'cleanup_handler' EXIT
    trap 'interrupt_handler' INT
    trap 'terminate_handler' TERM
}

# 错误处理器
error_handler() {
    local script_name="$1"
    local exit_code="$2"
    local line_no="$3"
    local command="$4"
    
    # 避免递归错误
    trap - ERR
    
    log ERROR "脚本执行失败: $script_name"
    log ERROR "退出代码: $exit_code"
    log ERROR "位置: 第 $line_no 行"
    log ERROR "命令: $command"
    
    # 记录到系统日志（如果可用）
    if command -v logger >/dev/null 2>&1; then
        logger -t "openclash-installer" "错误: $script_name 在第 $line_no 行失败 (代码: $exit_code)"
    fi
    
    # 根据错误代码提供建议
    suggest_solution "$exit_code" "$command"
    
    # 如果有错误日志文件，显示最后几行
    if [ -f "/tmp/openclash-error.log" ]; then
        log INFO "错误日志最后10行:"
        tail -10 "/tmp/openclash-error.log" >&2
    fi
    
    exit "$exit_code"
}

# 清理处理器
cleanup_handler() {
    local exit_code=$?
    
    # 清理临时文件
    cleanup_temp_files
    
    # 移除锁文件（如果存在）
    rm -f "/tmp/openclash-*.lock" 2>/dev/null || true
    
    log DEBUG "清理完成，退出代码: $exit_code"
}

# 中断处理器
interrupt_handler() {
    log WARN "用户中断执行 (Ctrl+C)"
    cleanup_temp_files
    exit 130
}

# 终止处理器
terminate_handler() {
    log WARN "收到终止信号"
    cleanup_temp_files
    exit 143
}

# 清理临时文件
cleanup_temp_files() {
    # 清理模式：只清理本脚本创建的临时文件
    local temp_patterns=(
        "/tmp/openclash-*.tmp"
        "/tmp/openclash-*.download"
        "/tmp/openclash-*.cache"
    )
    
    for pattern in "${temp_patterns[@]}"; do
        rm -f $pattern 2>/dev/null || true
    done
    
    # 清理空锁目录
    rmdir "/tmp/openclash-"* 2>/dev/null || true
}

# 根据错误代码提供建议
suggest_solution() {
    local exit_code="$1"
    local command="$2"
    
    case "$exit_code" in
        1)
            # 一般错误
            cat <<EOF

${BOLD}🔧 一般错误修复建议:${NC}
1. 检查脚本语法: ${CYAN}bash -n script.sh${NC}
2. 检查命令是否存在: ${CYAN}command -v <命令>${NC}
3. 检查文件权限: ${CYAN}ls -la <文件>${NC}
EOF
            ;;
        
        2)
            # 使用错误
            cat <<EOF

${BOLD}📖 用法帮助:${NC}
运行脚本时添加 --help 查看使用方法:
${CYAN}sh script.sh --help${NC}
EOF
            ;;
        
        4)
            # 网络错误
            cat <<EOF

${BOLD}🌐 网络错误修复建议:${NC}
1. 检查网络连接: ${CYAN}ping 8.8.8.8${NC}
2. 测试DNS解析: ${CYAN}nslookup github.com${NC}
3. 使用网络诊断: ${CYAN}sh tools/network-diagnose.sh${NC}
4. 尝试离线模式: ${CYAN}export OFFLINE_MODE=1${NC}
EOF
            ;;
        
        5)
            # 权限错误
            cat <<EOF

${BOLD}🔐 权限错误修复建议:${NC}
1. 检查当前用户: ${CYAN}whoami${NC}
2. 需要root权限: ${CYAN}sudo sh script.sh${NC}
3. 检查文件权限: ${CYAN}ls -la /path/to/file${NC}
EOF
            ;;
        
        6)
            # 配置文件错误
            cat <<EOF

${BOLD}📄 配置文件错误:${NC}
1. 检查配置文件语法: ${CYAN}cat /etc/openclash/config.yaml${NC}
2. 恢复默认配置: ${CYAN}rm -f /etc/openclash/config.yaml${NC}
3. 重新生成配置
EOF
            ;;
        
        7)
            # 磁盘空间不足
            cat <<EOF

${BOLD}💾 磁盘空间不足:${NC}
1. 检查磁盘使用: ${CYAN}df -h${NC}
2. 清理临时文件: ${CYAN}rm -rf /tmp/openclash-*${NC}
3. 清理旧日志: ${CYAN}rm -f /var/log/openclash*.log${NC}
EOF
            ;;
        
        22)
            # curl HTTP错误
            cat <<EOF

${BOLD}🌐 HTTP错误 (代码 22):${NC}
1. URL可能失效: ${CYAN}curl -I "$command"${NC}
2. 使用备用镜像: ${CYAN}export USE_MIRROR=jsdelivr${NC}
3. 手动下载文件
EOF
            ;;
        
        28)
            # curl超时
            cat <<EOF

${BOLD}⏱️  下载超时:${NC}
1. 增加超时时间: ${CYAN}export DOWNLOAD_TIMEOUT=60${NC}
2. 使用本地缓存: ${CYAN}export ENABLE_CACHE=1${NC}
3. 检查网络稳定性
EOF
            ;;
        
        *)
            # 未知错误
            if [[ "$command" =~ curl|wget ]]; then
                cat <<EOF

${BOLD}🌐 下载相关错误:${NC}
1. 检查网络代理: ${CYAN}env | grep -i proxy${NC}
2. 使用其他下载工具: ${CYAN}export PREFER_WGET=1${NC}
3. 手动下载后使用离线模式
EOF
            elif [[ "$command" =~ opkg|apk|apt ]]; then
                cat <<EOF

${BOLD}📦 包管理器错误:${NC}
1. 更新软件源: ${CYAN}opkg update${NC}
2. 检查网络连接: ${CYAN}ping downloads.openwrt.org${NC}
3. 使用国内镜像源
EOF
            elif [[ "$command" =~ rm|mv|cp ]]; then
                cat <<EOF

${BOLD}📁 文件操作错误:${NC}
1. 检查文件是否存在: ${CYAN}ls -la <文件>${NC}
2. 检查磁盘空间: ${CYAN}df -h${NC}
3. 检查文件权限: ${CYAN}ls -la <目录>${NC}
EOF
            fi
            ;;
    esac
    
    # 通用建议
    cat <<EOF

${BOLD}🔍 调试建议:${NC}
1. 启用详细输出: ${CYAN}export DEBUG=1${NC}
2. 查看详细日志: ${CYAN}tail -f /tmp/openclash-error.log${NC}
3. 手动执行失败命令: ${CYAN}$command${NC}

${BOLD}🚑 紧急恢复:${NC}
1. 重置OpenClash: ${CYAN}sh repair.sh${NC}
2. 完全卸载重装: ${CYAN}sh uninstall.sh && sh install.sh${NC}
3. 寻求社区帮助: https://github.com/slobys/openclash-auto-installer/issues
EOF
}

# 创建错误日志
setup_error_logging() {
    local log_file="${1:-/tmp/openclash-error.log}"
    
    # 确保日志目录存在
    mkdir -p "$(dirname "$log_file")"
    
    # 备份旧日志（保留最近5个）
    if [ -f "$log_file" ]; then
        for i in {4..1}; do
            [ -f "$log_file.$i" ] && mv -f "$log_file.$i" "$log_file.$((i+1))"
        done
        mv -f "$log_file" "$log_file.1"
    fi
    
    # 记录开始时间
    {
        echo "=== OpenClash 安装错误日志 ==="
        echo "开始时间: $(date)"
        echo "脚本: $(basename "$0")"
        echo "参数: $*"
        echo "用户: $(whoami)"
        echo "主机: $(hostname)"
        echo "系统: $(uname -a)"
        echo ""
    } > "$log_file"
    
    # 重定向stderr到日志文件（同时显示在终端）
    exec 2> >(tee -a "$log_file" >&2)
    
    log INFO "错误日志: $log_file"
}

# 检查运行环境
check_environment() {
    local requirements=("bash" "curl" "tar" "grep")
    local missing=()
    
    log INFO "检查运行环境..."
    
    # 检查命令
    for cmd in "${requirements[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log ERROR "缺少必要命令: ${missing[*]}"
        
        cat <<EOF

${BOLD}🔧 安装缺少的命令:${NC}
${CYAN}# OpenWrt${NC}
opkg update
opkg install ${missing[*]}

${CYAN}# Ubuntu/Debian${NC}
apt update
apt install ${missing[*]}

${CYAN}# CentOS/RHEL${NC}
yum install ${missing[*]}

${CYAN}# Alpine${NC}
apk add ${missing[*]}
EOF
        return 1
    fi
    
    # 检查磁盘空间
    local min_space_mb=50
    local available_space=$(df -m /tmp 2>/dev/null | awk 'NR==2 {print $4}')
    
    if [ -n "$available_space" ] && [ "$available_space" -lt "$min_space_mb" ]; then
        log WARN "磁盘空间不足: /tmp 仅剩 ${available_space}MB (需要至少 ${min_space_mb}MB)"
        
        # 尝试清理
        log INFO "尝试清理临时文件..."
        rm -rf /tmp/openclash-* 2>/dev/null || true
        
        # 重新检查
        available_space=$(df -m /tmp 2>/dev/null | awk 'NR==2 {print $4}')
        if [ "$available_space" -lt "$min_space_mb" ]; then
            log ERROR "清理后磁盘空间仍不足"
            return 1
        fi
    fi
    
    # 检查内存
    local min_mem_mb=128
    local available_mem=$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}')
    
    if [ -n "$available_mem" ] && [ "$available_mem" -lt "$min_mem_mb" ]; then
        log WARN "可用内存较低: ${available_mem}MB (建议至少 ${min_mem_mb}MB)"
    fi
    
    log SUCCESS "环境检查通过"
    return 0
}

# 用户确认（危险操作前）
confirm_action() {
    local message="$1"
    local default="${2:-no}"
    
    if [ "$FORCE_YES" = "1" ]; then
        log INFO "强制确认: $message"
        return 0
    fi
    
    local prompt
    if [ "$default" = "yes" ]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi
    
    printf "%b%s %s: " "$YELLOW" "$message" "$prompt" >&2
    read -r response
    
    case "$response" in
        [Yy][Ee][Ss]|[Yy])
            return 0
            ;;
        [Nn][Oo]|[Nn])
            return 1
            ;;
        "")
            # 使用默认值
            [ "$default" = "yes" ] && return 0 || return 1
            ;;
        *)
            # 无效输入，使用默认值
            log WARN "无效输入，使用默认值: $default"
            [ "$default" = "yes" ] && return 0 || return 1
            ;;
    esac
}

# 优雅退出
graceful_exit() {
    local exit_code="${1:-0}"
    local message="${2:-}"
    
    if [ -n "$message" ]; then
        if [ "$exit_code" -eq 0 ]; then
            log SUCCESS "$message"
        else
            log ERROR "$message"
        fi
    fi
    
    # 执行清理
    cleanup_temp_files
    
    # 移除锁
    rm -f "/tmp/$(basename "$0").lock" 2>/dev/null || true
    
    exit "$exit_code"
}

# 生成错误报告
generate_error_report() {
    local error_code="$1"
    local error_message="$2"
    local output_file="${3:-/tmp/openclash-error-report.txt}"
    
    {
        echo "=== OpenClash 错误报告 ==="
        echo "生成时间: $(date)"
        echo ""
        echo "=== 错误信息 ==="
        echo "代码: $error_code"
        echo "描述: $error_message"
        echo ""
        
        echo "=== 系统信息 ==="
        uname -a
        echo ""
        
        echo "=== 环境变量 ==="
        env | sort
        echo ""
        
        echo "=== 磁盘空间 ==="
        df -h
        echo ""
        
        echo "=== 内存使用 ==="
        free -h
        echo ""
        
        echo "=== 网络信息 ==="
        ip addr show 2>/dev/null || ifconfig 2>/dev/null || echo "无法获取网络信息"
        echo ""
        
        echo "=== 最近日志 ==="
        tail -50 /tmp/openclash-error.log 2>/dev/null || echo "无错误日志"
        echo ""
        
        echo "=== 建议操作 ==="
        suggest_solution "$error_code" "$error_message" | grep -v '^$'
        
    } > "$output_file"
    
    log INFO "错误报告已生成: $output_file"
    echo "请将此文件内容提交到 issue:"
    echo "https://github.com/slobys/openclash-auto-installer/issues"
}

# 如果直接运行，显示帮助
if [ "$(basename "$0")" = "error.sh" ]; then
    cat <<EOF
错误处理与恢复指南 v1.0

集成方法:
1. 在脚本开头添加:
   source "$(dirname "$0")/error.sh"
   
2. 设置错误陷阱:
   set_error_trap "\$(basename "\$0")"
   
3. 设置错误日志:
   setup_error_logging "/tmp/openclash-\$(basename "\$0").log"

可用函数:
- set_error_trap <脚本名>      # 设置错误处理
- setup_error_logging <文件>    # 设置日志记录
- check_environment            # 检查运行环境
- confirm_action "提示"         # 用户确认
- graceful_exit <代码> <消息>   # 优雅退出
- generate_error_report        # 生成错误报告

环境变量:
- LOG_LEVEL=DEBUG|INFO|WARN|ERROR
- FORCE_YES=1                  # 跳过确认
- DEBUG=1                      # 启用调试

示例:
  # 在脚本中使用
  source lib/error.sh
  set_error_trap "install.sh"
  setup_error_logging
  
  if ! check_environment; then
    graceful_exit 1 "环境检查失败"
  fi
  
  confirm_action "确定继续吗?" "yes" || graceful_exit 0 "用户取消"
EOF
fi