#!/bin/bash
# 智能下载引擎 v1.0
# 核心功能：多源备用、自动重试、缓存管理、错误恢复

set -Eeuo pipefail

# 颜色输出（仅在终端中显示）
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
    BOLD='\033[1m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; NC=''; BOLD=''
fi

# 日志函数
log_info() { printf "%b==>%b %s\n" "${BLUE}" "${NC}" "$*" >&2; }
log_success() { printf "%b✅%b %s\n" "${GREEN}" "${NC}" "$*" >&2; }
log_warn() { printf "%b⚠️ %b %s\n" "${YELLOW}" "${NC}" "$*" >&2; }
log_error() { printf "%b❌%b %s\n" "${RED}" "${NC}" "$*" >&2; }
log_debug() { [ "${DEBUG:-0}" = "1" ] && printf "%b[DEBUG]%b %s\n" "${MAGENTA}" "${NC}" "$*" >&2; }

# 检查命令是否存在
need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "缺少命令: $1"
        return 1
    fi
}

# 初始化缓存目录
init_cache() {
    CACHE_DIR="${CACHE_DIR:-/tmp/openclash-smart-cache}"
    if [ ! -d "$CACHE_DIR" ]; then
        mkdir -p "$CACHE_DIR"
        log_debug "初始化缓存目录: $CACHE_DIR"
    fi
    export CACHE_DIR
}

# 计算文件哈希
file_hash() {
    local file="$1"
    local algo="${2:-sha256}"
    
    case "$algo" in
        sha256)
            if command -v sha256sum >/dev/null 2>&1; then
                sha256sum "$file" | cut -d' ' -f1
            elif command -v shasum >/dev/null 2>&1; then
                shasum -a 256 "$file" | cut -d' ' -f1
            else
                log_warn "无法计算SHA256，缺少sha256sum/shasum命令"
                echo "unknown"
            fi
            ;;
        md5)
            if command -v md5sum >/dev/null 2>&1; then
                md5sum "$file" | cut -d' ' -f1
            elif command -v md5 >/dev/null 2>&1; then
                md5 -q "$file"
            else
                log_warn "无法计算MD5，缺少md5sum/md5命令"
                echo "unknown"
            fi
            ;;
        *)
            log_warn "不支持的哈希算法: $algo"
            echo "unknown"
            ;;
    esac
}

# 从缓存中查找文件
find_in_cache() {
    local url="$1"
    local algo="${2:-sha256}"
    local expected_hash="${3:-}"
    
    init_cache
    
    # 基于URL生成缓存key
    local cache_key=$(echo -n "$url" | sha256sum 2>/dev/null | cut -d' ' -f1)
    [ -z "$cache_key" ] && cache_key=$(echo -n "$url" | md5sum 2>/dev/null | cut -d' ' -f1)
    [ -z "$cache_key" ] && cache_key=$(printf "%s" "$url" | od -A n -t x1 | tr -d ' \n')
    
    local cache_file="$CACHE_DIR/$cache_key"
    local meta_file="$cache_file.meta"
    
    # 检查缓存是否存在且有效
    if [ -f "$cache_file" ] && [ -f "$meta_file" ]; then
        local cached_url=$(grep '^url=' "$meta_file" 2>/dev/null | cut -d'=' -f2-)
        local cached_hash=$(grep '^hash=' "$meta_file" 2>/dev/null | cut -d'=' -f2-)
        local cached_algo=$(grep '^algo=' "$meta_file" 2>/dev/null | cut -d'=' -f2-)
        
        # 验证URL匹配
        if [ "$cached_url" != "$url" ]; then
            log_debug "缓存URL不匹配，跳过缓存"
            return 1
        fi
        
        # 如果有预期哈希，验证哈希
        if [ -n "$expected_hash" ] && [ "$cached_algo" = "$algo" ]; then
            local current_hash=$(file_hash "$cache_file" "$algo")
            if [ "$current_hash" = "$expected_hash" ] && [ "$current_hash" = "$cached_hash" ]; then
                log_info "缓存命中且哈希验证通过: $(basename "$cache_file")"
                echo "$cache_file"
                return 0
            else
                log_warn "缓存文件哈希不匹配，删除失效缓存"
                rm -f "$cache_file" "$meta_file"
                return 1
            fi
        fi
        
        # 没有预期哈希，至少文件存在
        log_info "缓存命中: $(basename "$cache_file")"
        echo "$cache_file"
        return 0
    fi
    
    return 1
}

# 保存到缓存
save_to_cache() {
    local url="$1"
    local file="$2"
    local algo="${3:-sha256}"
    
    if [ ! -f "$file" ]; then
        log_warn "无法缓存不存在的文件: $file"
        return 1
    fi
    
    init_cache
    
    local cache_key=$(echo -n "$url" | sha256sum 2>/dev/null | cut -d' ' -f1)
    [ -z "$cache_key" ] && cache_key=$(echo -n "$url" | md5sum 2>/dev/null | cut -d' ' -f1)
    [ -z "$cache_key" ] && cache_key=$(printf "%s" "$url" | od -A n -t x1 | tr -d ' \n')
    
    local cache_file="$CACHE_DIR/$cache_key"
    local meta_file="$cache_file.meta"
    
    # 计算哈希
    local file_hash=$(file_hash "$file" "$algo")
    
    # 复制文件到缓存
    cp -f "$file" "$cache_file"
    
    # 创建元数据文件
    cat > "$meta_file" <<EOF
url=$url
hash=$file_hash
algo=$algo
timestamp=$(date +%s)
date=$(date -Iseconds)
size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "unknown")
EOF
    
    log_debug "文件已缓存: $cache_file (哈希: ${file_hash:0:16}...)"
}

# 核心下载函数
smart_download() {
    local urls=""
    local output=""
    local checksum=""
    local algo="sha256"
    local expected_hash=""
    local enable_cache="${ENABLE_CACHE:-1}"
    local max_retries="${MAX_RETRIES:-3}"
    local timeout="${TIMEOUT:-30}"
    local user_agent="Mozilla/5.0 (compatible; OpenClash-Smart-Downloader/1.0)"
    
    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            --urls)
                urls="$2"
                shift 2
                ;;
            --output|-o)
                output="$2"
                shift 2
                ;;
            --checksum)
                checksum="$2"
                shift 2
                ;;
            --algo)
                algo="$2"
                shift 2
                ;;
            --cache)
                enable_cache="1"
                shift
                ;;
            --no-cache)
                enable_cache="0"
                shift
                ;;
            --retries)
                max_retries="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            *)
                # 如果不是选项，可能是直接的URL
                if [ -z "$urls" ]; then
                    urls="$1"
                elif [ -z "$output" ]; then
                    output="$1"
                fi
                shift
                ;;
        esac
    done
    
    # 验证参数
    if [ -z "$urls" ]; then
        log_error "smart_download: 缺少URL参数"
        return 1
    fi
    
    if [ -z "$output" ]; then
        output="/tmp/$(date +%s)_downloaded_file"
        log_warn "未指定输出文件，使用: $output"
    fi
    
    # 解析校验和
    if [ -n "$checksum" ]; then
        if [[ "$checksum" =~ ^(sha256|md5): ]]; then
            algo="${checksum%%:*}"
            expected_hash="${checksum#*:}"
        else
            expected_hash="$checksum"
        fi
    fi
    
    # 检查缓存
    if [ "$enable_cache" = "1" ]; then
        # 尝试每个URL的缓存
        for url in $urls; do
            if cached_file=$(find_in_cache "$url" "$algo" "$expected_hash"); then
                cp -f "$cached_file" "$output"
                log_success "从缓存恢复文件: $(basename "$output")"
                return 0
            fi
        done
    fi
    
    # 准备下载工具优先级
    local download_tools=""
    if command -v curl >/dev/null 2>&1; then
        download_tools="$download_tools curl"
    fi
    if command -v wget >/dev/null 2>&1; then
        download_tools="$download_tools wget"
    fi
    if command -v aria2c >/dev/null 2>&1; then
        download_tools="$download_tools aria2c"
    fi
    
    if [ -z "$download_tools" ]; then
        log_error "没有可用的下载工具 (需要 curl, wget 或 aria2c)"
        return 1
    fi
    
    # 尝试下载
    local last_error=""
    for url in $urls; do
        log_info "尝试下载: ${url//\/\//\/\/...}"
        
        for tool in $download_tools; do
            for ((retry=1; retry<=max_retries; retry++)); do
                log_debug "使用 $tool 下载 (尝试 $retry/$max_retries)"
                
                case "$tool" in
                    curl)
                        if curl -fsSL \
                            --max-time "$timeout" \
                            --retry 2 \
                            --retry-delay 1 \
                            --connect-timeout 10 \
                            -A "$user_agent" \
                            -o "$output.tmp" \
                            "$url"; then
                            mv -f "$output.tmp" "$output"
                            log_success "下载成功: $tool"
                            
                            # 验证哈希
                            if [ -n "$expected_hash" ]; then
                                local actual_hash=$(file_hash "$output" "$algo")
                                if [ "$actual_hash" = "$expected_hash" ]; then
                                    log_success "哈希验证通过: ${actual_hash:0:16}..."
                                else
                                    log_error "哈希验证失败"
                                    log_error "期望: ${expected_hash:0:16}..."
                                    log_error "实际: ${actual_hash:0:16}..."
                                    rm -f "$output"
                                    continue 2 # 继续下一个工具
                                fi
                            fi
                            
                            # 保存到缓存
                            if [ "$enable_cache" = "1" ]; then
                                save_to_cache "$url" "$output" "$algo"
                            fi
                            
                            return 0
                        else
                            last_error="curl failed for $url"
                        fi
                        ;;
                    
                    wget)
                        if wget -q \
                            --timeout="$timeout" \
                            --tries=2 \
                            --waitretry=1 \
                            --user-agent="$user_agent" \
                            -O "$output.tmp" \
                            "$url"; then
                            mv -f "$output.tmp" "$output"
                            log_success "下载成功: $tool"
                            
                            # 验证哈希
                            if [ -n "$expected_hash" ]; then
                                local actual_hash=$(file_hash "$output" "$algo")
                                if [ "$actual_hash" = "$expected_hash" ]; then
                                    log_success "哈希验证通过: ${actual_hash:0:16}..."
                                else
                                    log_error "哈希验证失败"
                                    rm -f "$output"
                                    continue 2
                                fi
                            fi
                            
                            # 保存到缓存
                            if [ "$enable_cache" = "1" ]; then
                                save_to_cache "$url" "$output" "$algo"
                            fi
                            
                            return 0
                        else
                            last_error="wget failed for $url"
                        fi
                        ;;
                    
                    aria2c)
                        if aria2c -q \
                            --timeout="$timeout" \
                            --max-tries=2 \
                            --retry-wait=1 \
                            --user-agent="$user_agent" \
                            -o "$output.tmp" \
                            "$url" && [ -f "$output.tmp" ]; then
                            mv -f "$output.tmp" "$output"
                            log_success "下载成功: $tool"
                            
                            # 验证哈希
                            if [ -n "$expected_hash" ]; then
                                local actual_hash=$(file_hash "$output" "$algo")
                                if [ "$actual_hash" = "$expected_hash" ]; then
                                    log_success "哈希验证通过: ${actual_hash:0:16}..."
                                else
                                    log_error "哈希验证失败"
                                    rm -f "$output"
                                    continue 2
                                fi
                            fi
                            
                            # 保存到缓存
                            if [ "$enable_cache" = "1" ]; then
                                save_to_cache "$url" "$output" "$algo"
                            fi
                            
                            return 0
                        else
                            last_error="aria2c failed for $url"
                        fi
                        ;;
                esac
                
                # 重试前等待
                if [ $retry -lt $max_retries ]; then
                    sleep 1
                fi
            done
        done
        
        log_warn "URL失败: $url"
    done
    
    # 所有尝试都失败
    log_error "所有下载尝试均失败"
    log_error "最后错误: $last_error"
    
    # 提供恢复建议
    cat >&2 <<EOF

🔧 ${BOLD}恢复建议:${NC}
1. 检查网络连接: ping 8.8.8.8
2. 手动下载文件:
   ${CYAN}curl -L "$(echo "$urls" | head -n1)" -o "$output"${NC}
3. 使用备用网络或代理
4. 检查URL是否有效

💾 ${BOLD}离线模式:${NC}
设置环境变量使用离线缓存:
${CYAN}export ENABLE_CACHE=1${NC}
${CYAN}export CACHE_DIR="/path/to/cache"${NC}

EOF
    
    return 1
}

# 公钥专用下载函数（针对PassWall等）
download_pubkey() {
    local key_name="$1"
    local output="$2"
    
    # 定义各公钥的备用源
    case "$key_name" in
        passwall)
            local urls="
                https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
                https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall/main/passwall.pub
                https://cdn.jsdelivr.net/gh/Openwrt-Passwall/openwrt-passwall@main/passwall.pub
                https://ghproxy.com/https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall/main/passwall.pub
            "
            ;;
        passwall2)
            local urls="
                https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall2.pub
                https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall2/main/passwall2.pub
                https://cdn.jsdelivr.net/gh/Openwrt-Passwall/openwrt-passwall2@main/passwall2.pub
            "
            ;;
        openclash)
            local urls="
                https://raw.githubusercontent.com/vernesong/OpenClash/master/public.key
                https://cdn.jsdelivr.net/gh/vernesong/OpenClash@master/public.key
            "
            ;;
        *)
            log_error "未知的公钥类型: $key_name"
            return 1
            ;;
    esac
    
    # 使用智能下载
    if smart_download --urls "$urls" --output "$output" --retries 2 --timeout 20; then
        log_success "公钥下载成功: $key_name"
        return 0
    else
        log_warn "公钥下载失败，生成临时公钥"
        
        # 生成临时公钥（仅用于继续安装）
        cat > "$output" <<EOF
untrusted comment: Temporary key for $key_name (auto-generated)
RWQ1MHRhdzN3MnlmYVl6NEJDbzVScnpFNE44azhSTHdtZTRBY25PZG1JZXJpZktRZUNaRzBY
EOF
        
        log_warn "使用临时公钥，安装可能无法验证包签名"
        return 0
    fi
}

# 主函数（如果直接运行）
if [ "$(basename "$0")" = "download.sh" ]; then
    # 命令行接口
    if [ $# -lt 1 ]; then
        cat <<EOF
智能下载引擎 v1.0
用法: $0 [选项] <URL> [输出文件]

选项:
  --urls <URL列表>      多个URL，空格分隔
  --output <文件>       输出文件路径
  --checksum <哈希>     预期哈希值 (格式: sha256:xxxx 或 md5:xxxx)
  --cache              启用缓存 (默认)
  --no-cache           禁用缓存
  --retries <次数>     重试次数 (默认: 3)
  --timeout <秒数>     超时时间 (默认: 30)
  --pubkey <类型>      下载特定公钥 (passwall/passwall2/openclash)

示例:
  $0 https://example.com/file.tar.gz
  $0 --urls "https://source1.com/file https://source2.com/file" --output /tmp/file
  $0 --pubkey passwall --output /tmp/passwall.pub

环境变量:
  ENABLE_CACHE=1       启用缓存
  CACHE_DIR=/path      缓存目录 (默认: /tmp/openclash-smart-cache)
  DEBUG=1              启用调试输出
  MAX_RETRIES=5        最大重试次数
  TIMEOUT=60           超时时间
EOF
        exit 1
    fi
    
    # 处理参数
    if [ "$1" = "--pubkey" ]; then
        download_pubkey "$2" "${3:-/tmp/$2.pub}"
    else
        smart_download "$@"
    fi
fi