#!/bin/bash
# OpenClash 一键安装/更新脚本 (智能网络层增强版)
# 基于原 install.sh 重构，集成智能下载、缓存、错误处理

set -Eeuo pipefail

# 基础配置
SCRIPT_NAME="openclash-smart-install"
VERSION="2.0.0"

# 导入智能网络层库
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
source "${LIB_DIR}/error.sh"
source "${LIB_DIR}/download.sh"
source "${LIB_DIR}/network.sh"
source "${LIB_DIR}/cache.sh"

# 设置错误处理
set_error_trap "$SCRIPT_NAME"
setup_error_logging "/tmp/${SCRIPT_NAME}.log"

# 配置变量
LOCKDIR="/tmp/openclash-smart-install.lock"
TMP_ROOT="/tmp/openclash-smart-install"
API_URL="https://api.github.com/repos/vernesong/OpenClash/releases/latest"
CORE_REPO_BASE_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master"

# 默认参数
MODE="full"
RESTART_SERVICES="1"
FORCE_OPKG_UPDATE="1"
CORE_CHANNEL="auto"
OPKG_RETRY_SECONDS="10"
CHECK_ONLY="0"
SKIP_ENV_CHECK="0"
USE_MIRROR="auto"

# 显示用法
usage() {
    cat <<'EOF_USAGE'
OpenClash 智能安装脚本 v2.0
基于智能网络层，支持多源备用、缓存、离线模式

用法:
  sh install.sh [选项]

选项:
  --plugin-only       只安装/更新 OpenClash 插件，不安装 Meta 内核
  --core-only         只下载并安装 Meta 内核，不安装/更新插件
  --check-update      只检查是否有新版本，不执行安装/更新
  --meta-core         强制使用普通 Meta 内核
  --smart-core        强制使用 Smart Meta 内核
  --skip-restart      完成后不尝试重启 openclash / uhttpd
  --skip-opkg-update  跳过软件源更新
  --skip-env-check    跳过环境检查
  --offline           离线模式（使用缓存）
  --cache-dir <目录>  指定缓存目录
  --mirror <源>       指定镜像源 (github, jsdelivr, ghproxy, auto)
  --debug             启用调试输出
  -h, --help          显示帮助

智能功能:
  • 多源备用下载 (GitHub, jsDelivr, ghproxy)
  • 自动缓存管理
  • 网络诊断与自动恢复
  • 离线模式支持
  • 详细错误报告

环境变量:
  ENABLE_CACHE=1             启用缓存
  CACHE_DIR=/path            缓存目录
  USE_MIRROR=jsdelivr        指定镜像源
  OFFLINE_MODE=1             离线模式
  DEBUG=1                    调试模式
  FORCE_YES=1                跳过确认

示例:
  # 标准安装
  sh install.sh
  
  # 使用 jsdelivr 镜像
  sh install.sh --mirror jsdelivr
  
  # 离线安装（使用缓存）
  sh install.sh --offline
  
  # 仅检查更新
  sh install.sh --check-update
  
  # 调试模式
  DEBUG=1 sh install.sh --debug
EOF_USAGE
}

# 解析参数
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --plugin-only)
                MODE="plugin-only"
                ;;
            --core-only)
                MODE="core-only"
                ;;
            --meta-core)
                CORE_CHANNEL="meta"
                ;;
            --smart-core)
                CORE_CHANNEL="smart"
                ;;
            --check-update)
                CHECK_ONLY="1"
                ;;
            --skip-restart)
                RESTART_SERVICES="0"
                ;;
            --skip-opkg-update)
                FORCE_OPKG_UPDATE="0"
                ;;
            --skip-env-check)
                SKIP_ENV_CHECK="1"
                ;;
            --offline)
                export OFFLINE_MODE="1"
                export ENABLE_CACHE="1"
                ;;
            --cache-dir)
                export CACHE_DIR="$2"
                shift
                ;;
            --mirror)
                USE_MIRROR="$2"
                shift
                ;;
            --debug)
                export DEBUG="1"
                export LOG_LEVEL="DEBUG"
                ;;
            -h|--help)
                usage
                graceful_exit 0
                ;;
            *)
                log ERROR "未知参数: $1"
                usage
                graceful_exit 2
                ;;
        esac
        shift
    done
}

# 初始化
initialize() {
    log INFO "OpenClash 智能安装脚本 v${VERSION}"
    log INFO "执行模式: $MODE"
    log INFO "核心通道策略: $CORE_CHANNEL"
    
    # 检查锁
    if ! mkdir "$LOCKDIR" 2>/dev/null; then
        graceful_exit 1 "已有另一个安装/更新任务正在运行"
    fi
    
    # 创建临时目录
    mkdir -p "$TMP_ROOT"
    
    # 检查环境
    if [ "$SKIP_ENV_CHECK" != "1" ]; then
        check_environment || graceful_exit 1 "环境检查失败"
    fi
    
    # 网络诊断（如果不是离线模式）
    if [ "${OFFLINE_MODE:-0}" != "1" ]; then
        log INFO "执行网络诊断..."
        if ! test_basic_connectivity; then
            log WARN "网络连接异常，尝试继续..."
        fi
    fi
    
    # 显示缓存状态
    if [ "${ENABLE_CACHE:-0}" = "1" ]; then
        log INFO "缓存已启用: ${CACHE_DIR:-/tmp/openclash-smart-cache}"
        cache_stats 2>/dev/null || true
    fi
}

# 检测包管理器
detect_pkg_mgr() {
    if command -v opkg >/dev/null 2>&1; then
        echo "opkg"
    elif command -v apk >/dev/null 2>&1; then
        echo "apk"
    else
        graceful_exit 1 "未检测到 opkg 或 apk，当前系统暂不支持"
    fi
}

# 检测防火墙栈
detect_firewall_stack() {
    if command -v fw4 >/dev/null 2>&1 || [ -x /sbin/fw4 ] || [ -x /usr/sbin/fw4 ]; then
        echo "nft"
    else
        echo "iptables"
    fi
}

# 获取系统信息
get_system_info() {
    local arch=""
    local release=""
    
    if [ -f /etc/openwrt_release ]; then
        # shellcheck disable=SC1091
        . /etc/openwrt_release >/dev/null 2>&1 || true
        arch="${DISTRIB_ARCH:-}"
        release="${DISTRIB_RELEASE:-}"
    fi
    
    if [ -z "$arch" ]; then
        arch=$(uname -m 2>/dev/null || true)
    fi
    
    echo "$arch" "$release"
}

# 安装依赖包
install_dependencies() {
    local pkg_mgr="$1"
    local firewall_stack="$2"
    
    log INFO "安装依赖包 (管理器: $pkg_mgr, 防火墙: $firewall_stack)"
    
    case "$pkg_mgr" in
        opkg)
            if [ "$FORCE_OPKG_UPDATE" = "1" ]; then
                log INFO "更新 opkg 软件索引"
                if ! opkg update; then
                    if [ -e /var/lock/opkg.lock ]; then
                        log WARN "检测到 opkg.lock，等待后重试"
                        sleep "$OPKG_RETRY_SECONDS"
                        opkg update || graceful_exit 1 "opkg update 失败"
                    else
                        graceful_exit 1 "opkg update 失败"
                    fi
                fi
            else
                log INFO "跳过 opkg update"
            fi
            
            # 根据防火墙栈选择包
            if [ "$firewall_stack" = "nft" ]; then
                local packages="bash dnsmasq-full curl ca-bundle ip-full ruby ruby-yaml kmod-tun kmod-inet-diag unzip kmod-nft-tproxy luci-compat luci luci-base jsonfilter"
            else
                local packages="bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base jsonfilter"
            fi
            
            log INFO "安装: $packages"
            opkg install $packages || graceful_exit 1 "依赖包安装失败"
            ;;
            
        apk)
            if [ "$FORCE_OPKG_UPDATE" = "1" ]; then
                log INFO "更新 apk 软件索引"
                apk update || graceful_exit 1 "apk update 失败"
            else
                log INFO "跳过 apk update"
            fi
            
            if [ "$firewall_stack" = "nft" ]; then
                local packages="bash dnsmasq-full curl ca-bundle ip-full ruby ruby-yaml kmod-tun kmod-inet-diag unzip kmod-nft-tproxy luci-compat luci luci-base jsonfilter"
            else
                local packages="bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base jsonfilter"
            fi
            
            log INFO "安装: $packages"
            apk add $packages || graceful_exit 1 "依赖包安装失败"
            ;;
    esac
    
    log SUCCESS "依赖包安装完成"
}

# 获取OpenClash发布信息
fetch_openclash_release() {
    local api_url="$API_URL"
    
    # 应用镜像
    case "$USE_MIRROR" in
        jsdelivr)
            api_url="https://cdn.jsdelivr.net/gh/vernesong/OpenClash@core/api.github.com/repos/vernesong/OpenClash/releases/latest"
            ;;
        ghproxy)
            api_url="https://ghproxy.com/https://api.github.com/repos/vernesong/OpenClash/releases/latest"
            ;;
    esac
    
    local version_json="$TMP_ROOT/openclash_version.json"
    
    log INFO "获取 OpenClash 发布信息"
    
    # 使用智能下载
    if ! smart_download --urls "$api_url https://api.github.com/repos/vernesong/OpenClash/releases/latest" \
                       --output "$version_json" \
                       --retries 2 \
                       --timeout 30; then
        graceful_exit 4 "获取 OpenClash 发布信息失败"
    fi
    
    echo "$version_json"
}

# 检查更新
check_for_updates() {
    local pkg_mgr="$1"
    local version_json="$2"
    
    need_cmd jsonfilter
    
    local old_ver=""
    if command -v opkg >/dev/null 2>&1 && opkg status luci-app-openclash >/dev/null 2>&1; then
        old_ver=$(opkg status luci-app-openclash 2>/dev/null | sed -n 's/^Version: //p' | head -n1)
    fi
    
    local latest_tag=$(jsonfilter -i "$version_json" -e '@.tag_name' 2>/dev/null || true)
    
    log INFO "当前版本: ${old_ver:-未安装}"
    log INFO "最新版本: ${latest_tag:-未知}"
    
    if [ -z "$old_ver" ]; then
        log INFO "未安装 OpenClash，可执行安装"
        return 1  # 需要安装
    fi
    
    # 简单版本比较
    old_ver=${old_ver#v}
    latest_tag=${latest_tag#v}
    
    if [ "$old_ver" = "$latest_tag" ]; then
        log SUCCESS "已经是最新版本"
        return 0  # 不需要更新
    else
        log INFO "发现新版本: $latest_tag"
        return 1  # 需要更新
    fi
}

# 安装OpenClash包
install_openclash_package() {
    local pkg_mgr="$1"
    local version_json="$2"
    
    need_cmd jsonfilter
    
    # 获取包URL
    local package_url=""
    if [ "$pkg_mgr" = "opkg" ]; then
        package_url=$(jsonfilter -i "$version_json" -e '@.assets[*].browser_download_url' | grep -E '/luci-app-openclash_.*_all\.ipk$' | head -n1 || true)
    else
        package_url=$(jsonfilter -i "$version_json" -e '@.assets[*].browser_download_url' | grep -E '/luci-app-openclash-.*\.apk$' | head -n1 || true)
    fi
    
    [ -n "$package_url" ] || graceful_exit 1 "未找到适合的安装包"
    
    # 应用镜像
    case "$USE_MIRROR" in
        jsdelivr)
            package_url="${package_url//raw.githubusercontent.com/cdn.jsdelivr.net\/gh}"
            package_url="${package_url//github.com/cdn.jsdelivr.net\/gh}"
            ;;
        ghproxy)
            package_url="https://ghproxy.com/$package_url"
            ;;
    esac
    
    local package_file="$TMP_ROOT/openclash-package.${pkg_mgr}"
    
    log INFO "下载 OpenClash 包: ${package_url##*/}"
    
    # 使用智能下载
    if ! smart_download --urls "$package_url" \
                       --output "$package_file" \
                       --retries 3 \
                       --timeout 60; then
        graceful_exit 4 "下载 OpenClash 包失败"
    fi
    
    # 安装包
    log INFO "安装 OpenClash 包"
    case "$pkg_mgr" in
        opkg)
            opkg install "$package_file" || graceful_exit 1 "安装 OpenClash 失败"
            ;;
        apk)
            apk add --force-overwrite --clean-protected --allow-untrusted "$package_file" || \
                graceful_exit 1 "安装 OpenClash 失败"
            ;;
    esac
    
    log SUCCESS "OpenClash 包安装完成"
}

# 安装Meta内核
install_meta_core() {
    local core_channel="$1"
    local arch_info="$2"
    
    log INFO "安装 Meta 内核 (通道: $core_channel, 架构: $arch_info)"
    
    # 检测内核候选
    local candidates=$(detect_core_candidates "$arch_info")
    if [ -z "$candidates" ]; then
        log WARN "无法识别的 CPU 架构: $arch_info"
        log WARN "请在 OpenClash 页面中手动下载匹配内核"
        return 0
    fi
    
    log INFO "候选内核: $candidates"
    
    # 构建下载URL
    local base_url="$CORE_REPO_BASE_URL/$core_channel"
    
    # 应用镜像
    case "$USE_MIRROR" in
        jsdelivr)
            base_url="https://cdn.jsdelivr.net/gh/vernesong/OpenClash@core/master/$core_channel"
            ;;
        ghproxy)
            base_url="https://ghproxy.com/https://raw.githubusercontent.com/vernesong/OpenClash/core/master/$core_channel"
            ;;
    esac
    
    local core_file="$TMP_ROOT/openclash-core.tar.gz"
    
    # 尝试下载每个候选
    for candidate in $candidates; do
        local url="$base_url/$candidate"
        log INFO "尝试下载: $candidate"
        
        if smart_download --urls "$url" \
                         --output "$core_file" \
                         --retries 2 \
                         --timeout 40; then
            log SUCCESS "下载成功: $candidate"
            
            # 解压安装
            extract_and_install_core "$core_file"
            return 0
        fi
    done
    
    log WARN "自动下载内核失败"
    log WARN "请手动下载适合的内核并放置到 /etc/openclash/core/"
    return 1
}

# 解压安装内核
extract_and_install_core() {
    local core_file="$1"
    local tmp_dir="$TMP_ROOT/core-extract"
    
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"
    mkdir -p /etc/openclash/core
    
    log INFO "解压内核文件"
    tar zxf "$core_file" -C "$tmp_dir" >/dev/null 2>&1 || \
        graceful_exit 1 "解压内核失败"
    
    # 查找可执行文件
    local bin_file=$(find "$tmp_dir" -type f -perm -u+x 2>/dev/null | head -n1 || true)
    [ -n "$bin_file" ] || bin_file=$(find "$tmp_dir" -type f 2>/dev/null | head -n1 || true)
    [ -n "$bin_file" ] || graceful_exit 1 "内核包中未找到可用文件"
    
    # 备份旧内核
    if [ -f /etc/openclash/core/clash_meta ]; then
        cp -f /etc/openclash/core/clash_meta /etc/openclash/core/clash_meta.bak 2>/dev/null || true
    fi
    
    # 安装新内核
    cp -f "$bin_file" /etc/openclash/core/clash_meta
    chmod 0755 /etc/openclash/core/clash_meta
    
    log SUCCESS "Meta 内核已安装到 /etc/openclash/core/clash_meta"
}

# 重启服务
restart_services() {
    if [ "$RESTART_SERVICES" != "1" ]; then
        log INFO "跳过服务重启"
        return 0
    fi
    
    log INFO "重启相关服务"
    
    # 重启OpenClash
    if [ -x /etc/init.d/openclash ]; then
        log INFO "重启 OpenClash 服务"
        /etc/init.d/openclash restart >/dev/null 2>&1 || \
            log WARN "OpenClash 服务重启失败"
    fi
    
    # 清理LuCI缓存
    log INFO "清理 LuCI 缓存"
    rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true
    
    # 重启rpcd
    if [ -x /etc/init.d/rpcd ]; then
        log INFO "重启 rpcd"
        /etc/init.d/rpcd restart >/dev/null 2>&1 || \
            log WARN "rpcd 重启失败"
    fi
    
    log SUCCESS "服务重启完成"
}

# 显示版本信息
show_versions() {
    log INFO "=== 版本信息 ==="
    
    # 插件版本
    if command -v opkg >/dev/null 2>&1; then
        local plugin_ver=$(opkg status luci-app-openclash 2>/dev/null | sed -n 's/^Version: //p' | head -n1)
        [ -n "$plugin_ver" ] && log INFO "OpenClash 插件: $plugin_ver"
    fi
    
    # 内核版本
    if [ -x /etc/openclash/core/clash_meta ]; then
        local core_ver=$(/etc/openclash/core/clash_meta -v 2>/dev/null | head -n1 || true)
        [ -n "$core_ver" ] && log INFO "Meta 内核: $core_ver"
    fi
}

# 主函数
main() {
    parse_args "$@"
    initialize
    
    # 检测环境
    local pkg_mgr=$(detect_pkg_mgr)
    local firewall_stack=$(detect_firewall_stack)
    local system_info=$(get_system_info)
    local arch=$(echo "$system_info" | awk '{print $1}')
    local release=$(echo "$system_info" | awk '{print $2}')
    
    log INFO "系统信息: 架构=$arch, 版本=$release"
    log INFO "包管理器: $pkg_mgr"
    log INFO "防火墙栈: $firewall_stack"
    
    # 仅检查更新
    if [ "$CHECK_ONLY" = "1" ]; then
        local version_json=$(fetch_openclash_release)
        check_for_updates "$pkg_mgr" "$version_json"
        graceful_exit 0 "更新检查完成"
    fi
    
    # 安装插件
    if [ "$MODE" = "full" ] || [ "$MODE" = "plugin-only" ]; then
        install_dependencies "$pkg_mgr" "$firewall_stack"
        local version_json=$(fetch_openclash_release)
        install_openclash_package "$pkg_mgr" "$version_json"
    fi
    
    # 安装内核
    if [ "$MODE" = "full" ] || [ "$MODE" = "core-only" ]; then
        # 确定核心通道
        local resolved_channel="$CORE_CHANNEL"
        if [ "$CORE_CHANNEL" = "auto" ]; then
            resolved_channel=$(detect_smart_core_enabled)
            log INFO "自动选择核心通道: $resolved_channel"
        fi
        
        install_meta_core "$resolved_channel" "$arch"
    fi
    
    # 重启服务
    restart_services
    
    # 显示版本
    show_versions
    
    # 完成提示
    log SUCCESS "OpenClash 安装/更新完成!"
    cat <<EOF

🎉 安装成功!

下一步建议:
1. 刷新浏览器页面
2. 进入 服务 → OpenClash
3. 导入订阅配置
4. 启动 OpenClash

📖 更多帮助:
- 查看日志: tail -f /tmp/openclash-error.log
- 修复问题: sh repair.sh
- 卸载: sh uninstall.sh

💾 缓存管理:
- 查看缓存: sh tools/cache.sh stats
- 清理缓存: sh tools/cache.sh clean

EOF
}

# 运行主函数
main "$@"

# 优雅退出
graceful_exit 0 "脚本执行完成"