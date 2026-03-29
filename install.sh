#!/bin/sh
set -eu

# OpenClash 一键安装 / 更新脚本
# 适用场景：OpenWrt / iStoreOS / ImmortalWrt 等兼容 opkg / apk 的环境

LOCKDIR="/tmp/openclash-auto-install.lock"
TMP_ROOT="/tmp/openclash-auto-install"
API_URL="https://api.github.com/repos/vernesong/OpenClash/releases/latest"
CORE_REPO_BASE_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master"
SCRIPT_NAME="openclash-auto-install"
MODE="full"
RESTART_SERVICES="1"
FORCE_OPKG_UPDATE="1"
CORE_CHANNEL="auto"
OPKG_RETRY_SECONDS="10"

cleanup() {
    rm -rf "$TMP_ROOT"
    rmdir "$LOCKDIR" 2>/dev/null || true
}

log() {
    printf '%s\n' "==> $*"
}

warn() {
    printf '%s\n' "[WARN] $*" >&2
}

die() {
    printf '%s\n' "[ERROR] $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

usage() {
    cat <<'EOF_USAGE'
用法:
  sh install.sh [选项]

选项:
  --plugin-only       只安装/更新 OpenClash 插件，不安装 Meta 内核
  --core-only         只下载并安装 Meta 内核，不安装/更新插件
  --meta-core         强制使用普通 Meta 内核
  --smart-core        强制使用 Smart Meta 内核
  --skip-restart      完成后不尝试重启 openclash / uhttpd
  --skip-opkg-update  跳过软件源更新（适合你已手动 opkg update 后再次执行）
  -h, --help          显示帮助
EOF_USAGE
}

parse_args() {
    while [ "$#" -gt 0 ]; do
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
            --skip-restart)
                RESTART_SERVICES="0"
                ;;
            --skip-opkg-update)
                FORCE_OPKG_UPDATE="0"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "未知参数: $1"
                ;;
        esac
        shift
    done
}

trap cleanup EXIT INT TERM

parse_args "$@"

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    die "已有另一个安装/更新任务正在运行"
fi

mkdir -p "$TMP_ROOT"

get_distr_arch() {
    if [ -f /etc/openwrt_release ]; then
        # shellcheck disable=SC1091
        . /etc/openwrt_release >/dev/null 2>&1 || true
        printf '%s' "${DISTRIB_ARCH:-}"
    else
        printf ''
    fi
}

get_distr_release() {
    if [ -f /etc/openwrt_release ]; then
        # shellcheck disable=SC1091
        . /etc/openwrt_release >/dev/null 2>&1 || true
        printf '%s' "${DISTRIB_RELEASE:-}"
    else
        printf ''
    fi
}

has_flag() {
    printf ' %s ' "${CPU_FLAGS:-}" | grep -qw "$1"
}

detect_x86_level() {
    CPU_FLAGS="$(grep -m1 '^flags' /proc/cpuinfo 2>/dev/null | cut -d: -f2- || true)"

    if has_flag avx512f && has_flag avx512bw && has_flag avx512cd && has_flag avx512dq && has_flag avx512vl; then
        printf 'v4'
        return
    fi

    if has_flag avx && has_flag avx2 && has_flag bmi1 && has_flag bmi2 && has_flag f16c && has_flag fma && has_flag lzcnt && has_flag movbe && has_flag xsave; then
        printf 'v3'
        return
    fi

    if has_flag cx16 && has_flag lahf_lm && has_flag popcnt && has_flag ssse3 && has_flag sse4_1 && has_flag sse4_2; then
        printf 'v2'
        return
    fi

    printf 'v1'
}

detect_pkg_mgr() {
    if command -v opkg >/dev/null 2>&1; then
        printf 'opkg'
    elif command -v apk >/dev/null 2>&1; then
        printf 'apk'
    else
        die "未检测到 opkg 或 apk，当前系统暂不支持"
    fi
}

detect_firewall_stack() {
    if command -v fw4 >/dev/null 2>&1 || [ -x /sbin/fw4 ] || [ -x /usr/sbin/fw4 ]; then
        printf 'nft'
    else
        printf 'iptables'
    fi
}

detect_core_candidates() {
    RAW_ARCH="$(uname -m 2>/dev/null || true)"
    DIST_ARCH="$(get_distr_arch)"
    MATCH_STR="$RAW_ARCH $DIST_ARCH"

    case "$MATCH_STR" in
        *x86_64*|*amd64*)
            X86_LEVEL="$(detect_x86_level)"
            case "$X86_LEVEL" in
                v4) printf '%s' 'clash-linux-amd64-v4.tar.gz clash-linux-amd64-v3.tar.gz clash-linux-amd64-v2.tar.gz clash-linux-amd64.tar.gz' ;;
                v3) printf '%s' 'clash-linux-amd64-v3.tar.gz clash-linux-amd64-v2.tar.gz clash-linux-amd64.tar.gz' ;;
                v2) printf '%s' 'clash-linux-amd64-v2.tar.gz clash-linux-amd64.tar.gz' ;;
                *)  printf '%s' 'clash-linux-amd64.tar.gz' ;;
            esac
            ;;
        *aarch64*|*arm64*|*armv8*)
            printf '%s' 'clash-linux-arm64.tar.gz'
            ;;
        *armv7*|*arm_cortex-a7*|*arm_cortex-a9*|*arm_cortex-a15*)
            printf '%s' 'clash-linux-armv7.tar.gz'
            ;;
        *armv6*|*arm1176*|*arm_arm1176*)
            printf '%s' 'clash-linux-armv6.tar.gz'
            ;;
        *armv5*|*arm926*)
            printf '%s' 'clash-linux-armv5.tar.gz'
            ;;
        *)
            printf ''
            ;;
    esac
}

download_file() {
    URL="$1"
    OUT="$2"
    if ! curl -fsSL --retry 3 --connect-timeout 15 "$URL" -o "$OUT"; then
        return 1
    fi
    return 0
}

is_openclash_installed() {
    PKG_MGR="$1"
    case "$PKG_MGR" in
        opkg)
            opkg status luci-app-openclash 2>/dev/null | grep -q '^Status: .* installed'
            ;;
        apk)
            apk info -e luci-app-openclash >/dev/null 2>&1
            ;;
    esac
}

get_installed_openclash_version() {
    PKG_MGR="$1"
    if ! is_openclash_installed "$PKG_MGR"; then
        return 0
    fi

    case "$PKG_MGR" in
        opkg)
            opkg status luci-app-openclash 2>/dev/null | sed -n 's/^Version: //p' | head -n1
            ;;
        apk)
            apk info -a luci-app-openclash 2>/dev/null | sed -n 's/^version: //p' | head -n1
            ;;
    esac
}

maybe_update_index_opkg() {
    if [ "$FORCE_OPKG_UPDATE" != "1" ]; then
        log "按参数跳过 opkg update"
        return 0
    fi

    log "更新 opkg 软件索引"
    if opkg update; then
        return 0
    fi

    if [ -e /var/lock/opkg.lock ]; then
        warn "检测到 opkg.lock，可能有其他包管理任务正在运行"
        warn "将在 ${OPKG_RETRY_SECONDS} 秒后重试一次 opkg update"
        sleep "$OPKG_RETRY_SECONDS"
        if opkg update; then
            return 0
        fi
        die "opkg update 仍然失败；如你刚执行过软件源刷新，可改用 --skip-opkg-update 重试"
    fi

    die "opkg update 失败"
}

maybe_update_index_apk() {
    if [ "$FORCE_OPKG_UPDATE" = "1" ]; then
        log "更新 apk 软件索引"
        apk update
    else
        log "按参数跳过 apk update"
    fi
}

install_dependencies_opkg() {
    FIREWALL_STACK="$1"
    maybe_update_index_opkg

    if [ "$FIREWALL_STACK" = "nft" ]; then
        PKGS="bash dnsmasq-full curl ca-bundle ip-full ruby ruby-yaml kmod-tun kmod-inet-diag unzip kmod-nft-tproxy luci-compat luci luci-base jsonfilter"
    else
        PKGS="bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base jsonfilter"
    fi

    log "安装依赖包"
    opkg install $PKGS
}

install_dependencies_apk() {
    FIREWALL_STACK="$1"
    maybe_update_index_apk

    if [ "$FIREWALL_STACK" = "nft" ]; then
        PKGS="bash dnsmasq-full curl ca-bundle ip-full ruby ruby-yaml kmod-tun kmod-inet-diag unzip kmod-nft-tproxy luci-compat luci luci-base jsonfilter"
    else
        PKGS="bash iptables dnsmasq-full curl ca-bundle ipset ip-full iptables-mod-tproxy iptables-mod-extra ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base jsonfilter"
    fi

    log "安装依赖包"
    apk add $PKGS
}

fetch_openclash_release_meta() {
    VERSION_JSON="$TMP_ROOT/openclash_version.json"
    printf '%s\n' "==> 获取 OpenClash 最新发布信息" >&2
    download_file "$API_URL" "$VERSION_JSON" || die "获取 OpenClash 发布信息失败"
}

get_latest_tag() {
    VERSION_JSON="$TMP_ROOT/openclash_version.json"
    jsonfilter -i "$VERSION_JSON" -e '@.tag_name' 2>/dev/null || true
}

fetch_openclash_package_url() {
    PKG_MGR="$1"
    VERSION_JSON="$TMP_ROOT/openclash_version.json"

    if [ ! -f "$VERSION_JSON" ]; then
        fetch_openclash_release_meta
    fi

    if [ "$PKG_MGR" = "opkg" ]; then
        URL="$(jsonfilter -i "$VERSION_JSON" -e '@.assets[*].browser_download_url' | grep -E '/luci-app-openclash_.*_all\.ipk$' | head -n1 || true)"
        [ -n "$URL" ] || URL="$(jsonfilter -i "$VERSION_JSON" -e '@.assets[*].browser_download_url' | grep '\.ipk$' | head -n1 || true)"
    else
        URL="$(jsonfilter -i "$VERSION_JSON" -e '@.assets[*].browser_download_url' | grep -E '/luci-app-openclash-.*\.apk$' | head -n1 || true)"
        [ -n "$URL" ] || URL="$(jsonfilter -i "$VERSION_JSON" -e '@.assets[*].browser_download_url' | grep '\.apk$' | head -n1 || true)"
    fi

    [ -n "$URL" ] || die "未找到匹配当前包管理器的 OpenClash 安装包"
    printf '%s' "$URL"
}

install_openclash_package() {
    PKG_MGR="$1"
    DOWNLOAD_URL="$2"

    case "$PKG_MGR" in
        opkg)
            PKG_FILE="$TMP_ROOT/openclash.ipk"
            log "下载 OpenClash IPK: $DOWNLOAD_URL"
            download_file "$DOWNLOAD_URL" "$PKG_FILE" || die "下载 OpenClash IPK 失败"
            opkg install "$PKG_FILE"
            ;;
        apk)
            PKG_FILE="$TMP_ROOT/openclash.apk"
            log "下载 OpenClash APK: $DOWNLOAD_URL"
            download_file "$DOWNLOAD_URL" "$PKG_FILE" || die "下载 OpenClash APK 失败"
            apk add -q --force-overwrite --clean-protected --allow-untrusted "$PKG_FILE"
            ;;
        *)
            die "未知包管理器: $PKG_MGR"
            ;;
    esac
}

detect_smart_core_enabled() {
    if command -v uci >/dev/null 2>&1; then
        SMART_VALUE="$(uci -q get openclash.config.enable_meta_core 2>/dev/null || true)"
        case "$SMART_VALUE" in
            1|true|TRUE|True|on|ON|yes|YES)
                printf '%s' 'smart'
                return
                ;;
        esac

        SMART_VALUE="$(uci -q get openclash.config.enable_meta_core_fast 2>/dev/null || true)"
        case "$SMART_VALUE" in
            1|true|TRUE|True|on|ON|yes|YES)
                printf '%s' 'smart'
                return
                ;;
        esac
    fi

    printf '%s' 'meta'
}

resolve_core_channel() {
    case "$CORE_CHANNEL" in
        smart)
            printf '%s' 'smart'
            ;;
        meta)
            printf '%s' 'meta'
            ;;
        auto)
            detect_smart_core_enabled
            ;;
        *)
            printf '%s' 'meta'
            ;;
    esac
}

download_core() {
    CHANNEL="$1"
    CANDIDATES="$2"
    TMP_CORE="$TMP_ROOT/openclash-core.tar.gz"
    CORE_BASE_URL="$CORE_REPO_BASE_URL/$CHANNEL"

    rm -f "$TMP_CORE"

    for file in $CANDIDATES; do
        URL="$CORE_BASE_URL/$file"
        log "尝试下载 ${CHANNEL} 内核: $URL"
        if download_file "$URL" "$TMP_CORE"; then
            CHOSEN_CORE_FILE="$file"
            CHOSEN_CORE_CHANNEL="$CHANNEL"
            export CHOSEN_CORE_FILE CHOSEN_CORE_CHANNEL
            return 0
        fi
    done

    return 1
}

extract_and_install_core() {
    TMP_CORE="$TMP_ROOT/openclash-core.tar.gz"
    TMP_DIR="$TMP_ROOT/core-extract"

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    mkdir -p /etc/openclash/core

    tar zxf "$TMP_CORE" -C "$TMP_DIR" >/dev/null 2>&1 || die "解压 Meta 内核失败"

    BIN_FILE="$(find "$TMP_DIR" -type f -perm -u+x 2>/dev/null | head -n1 || true)"
    [ -n "$BIN_FILE" ] || BIN_FILE="$(find "$TMP_DIR" -type f 2>/dev/null | head -n1 || true)"
    [ -n "$BIN_FILE" ] || die "内核压缩包中未找到可用文件"

    if [ -f /etc/openclash/core/clash_meta ]; then
        cp -f /etc/openclash/core/clash_meta /etc/openclash/core/clash_meta.bak 2>/dev/null || true
    fi

    cp -f "$BIN_FILE" /etc/openclash/core/clash_meta
    chmod 0755 /etc/openclash/core/clash_meta

    log "Meta 内核已安装到 /etc/openclash/core/clash_meta"
}

restart_related_services() {
    CHANGED="${1:-1}"

    if [ "$RESTART_SERVICES" != "1" ]; then
        log "按参数跳过服务重启"
        return 0
    fi

    if [ "$CHANGED" != "1" ]; then
        log "版本未变化且未强制变更，跳过服务重启"
        return 0
    fi

    if [ -x /etc/init.d/openclash ]; then
        log "尝试重启 OpenClash 服务"
        /etc/init.d/openclash restart >/dev/null 2>&1 || warn "OpenClash 服务重启失败，可稍后手动重启"
    fi

    log "清理 LuCI 菜单缓存"
    rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true

    if [ -x /etc/init.d/rpcd ]; then
        log "尝试重启 rpcd"
        /etc/init.d/rpcd restart >/dev/null 2>&1 || warn "rpcd 重启失败，可稍后手动重启"
    fi
}

show_runtime_versions() {
    if [ -n "${NEW_VER:-}" ]; then
        log "当前 OpenClash 插件版本: ${NEW_VER}"
    elif [ -n "${OLD_VER:-}" ]; then
        log "当前 OpenClash 插件版本: ${OLD_VER}"
    fi

    if [ -n "${CHOSEN_CORE_CHANNEL:-}" ]; then
        log "本次安装核心通道: ${CHOSEN_CORE_CHANNEL}"
    fi

    if [ -x /etc/openclash/core/clash_meta ]; then
        CORE_VER="$(/etc/openclash/core/clash_meta -v 2>/dev/null | head -n1 || true)"
        if [ -n "$CORE_VER" ]; then
            log "当前 Meta 内核版本: $CORE_VER"
        else
            warn "已检测到 clash_meta 文件，但未能读取版本信息"
        fi
    else
        warn "未检测到 /etc/openclash/core/clash_meta"
    fi
}

show_summary() {
    cat <<EOF_SUMMARY
==> 完成
==> 建议下一步：
 1. 刷新 LuCI 页面
 2. 进入 服务 -> OpenClash
 3. 如果页面中的内核版本未及时刷新，请以命令行输出为准
 4. 导入订阅后再启动
EOF_SUMMARY
}

main() {
    need_cmd curl
    need_cmd tar
    need_cmd grep
    need_cmd head
    need_cmd find
    need_cmd sed

    PKG_MGR="$(detect_pkg_mgr)"
    FIREWALL_STACK="$(detect_firewall_stack)"
    RAW_ARCH="$(uname -m 2>/dev/null || true)"
    DIST_ARCH="$(get_distr_arch)"
    DIST_RELEASE="$(get_distr_release)"
    OLD_VER="$(get_installed_openclash_version "$PKG_MGR" || true)"
    PLUGIN_CHANGED="0"
    CORE_CHANGED="0"

    log "脚本名称: $SCRIPT_NAME"
    log "执行模式: $MODE"
    log "核心通道策略: $CORE_CHANNEL"
    log "包管理器: $PKG_MGR"
    log "防火墙栈: $FIREWALL_STACK"
    log "uname -m: ${RAW_ARCH:-unknown}"
    log "DISTRIB_ARCH: ${DIST_ARCH:-unknown}"
    [ -n "$DIST_RELEASE" ] && log "DISTRIB_RELEASE: $DIST_RELEASE"
    log "当前已安装版本: ${OLD_VER:-not installed}"

    case "$MODE" in
        full|plugin-only)
            case "$PKG_MGR" in
                opkg) install_dependencies_opkg "$FIREWALL_STACK" ;;
                apk) install_dependencies_apk "$FIREWALL_STACK" ;;
            esac
            need_cmd jsonfilter
            fetch_openclash_release_meta
            LATEST_TAG="$(get_latest_tag)"
            [ -n "$LATEST_TAG" ] && log "OpenClash 最新发布标签: $LATEST_TAG"
            PACKAGE_URL="$(fetch_openclash_package_url "$PKG_MGR")"
            log "安装 / 更新 OpenClash 插件"
            install_openclash_package "$PKG_MGR" "$PACKAGE_URL"
            NEW_VER="$(get_installed_openclash_version "$PKG_MGR" || true)"
            log "安装后版本: ${NEW_VER:-unknown}"
            if [ "${OLD_VER:-}" != "${NEW_VER:-}" ]; then
                PLUGIN_CHANGED="1"
            fi
            ;;
    esac

    case "$MODE" in
        full|core-only)
            CORE_CANDIDATES="$(detect_core_candidates)"
            if [ -z "$CORE_CANDIDATES" ]; then
                warn "未识别的 CPU 架构，无法自动匹配 Meta 内核"
                warn "请在 OpenClash 页面中手动下载匹配内核"
                show_summary
                exit 0
            fi

            RESOLVED_CORE_CHANNEL="$(resolve_core_channel)"
            log "本次使用核心通道: $RESOLVED_CORE_CHANNEL"
            log "候选 Meta 内核: $CORE_CANDIDATES"
            if download_core "$RESOLVED_CORE_CHANNEL" "$CORE_CANDIDATES"; then
                log "已下载匹配内核包: $CHOSEN_CORE_FILE"
                extract_and_install_core
                CORE_CHANGED="1"
            else
                warn "自动下载 ${RESOLVED_CORE_CHANNEL} 内核失败，请在 OpenClash 页面手动下载"
                show_summary
                exit 0
            fi
            ;;
    esac

    if [ "$PLUGIN_CHANGED" = "1" ] || [ "$CORE_CHANGED" = "1" ]; then
        CHANGED="1"
    else
        CHANGED="0"
    fi

    restart_related_services "$CHANGED"
    show_runtime_versions
    show_summary
}

main "$@"
