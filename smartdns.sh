#!/bin/sh
set -eu

LOCKDIR="/tmp/smartdns-install.lock"
TMP_ROOT="/tmp/smartdns-install"
SMARTDNS_API="https://api.github.com/repos/pymumu/smartdns/releases/latest"
RESTART_SERVICES="1"
FORCE_PKG_UPDATE="1"

cleanup() {
    rm -rf "$TMP_ROOT"
    rmdir "$LOCKDIR" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

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
  sh smartdns.sh [选项]

选项:
  --skip-restart      完成后不尝试启用 / 重启 smartdns
  --skip-pkg-update   跳过 opkg update / apk update
  -h, --help          显示帮助
EOF_USAGE
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --skip-restart)
                RESTART_SERVICES="0"
                ;;
            --skip-pkg-update)
                FORCE_PKG_UPDATE="0"
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

detect_pkg_mgr() {
    if command -v opkg >/dev/null 2>&1; then
        printf 'opkg'
    elif command -v apk >/dev/null 2>&1; then
        printf 'apk'
    else
        die "未检测到 opkg 或 apk，当前系统暂不支持"
    fi
}

get_distr_arch() {
    if [ -f /etc/openwrt_release ]; then
        # shellcheck disable=SC1091
        . /etc/openwrt_release >/dev/null 2>&1 || true
        printf '%s' "${DISTRIB_ARCH:-}"
    else
        printf ''
    fi
}

detect_smartdns_arch() {
    RAW_ARCH="$(uname -m 2>/dev/null || true)"
    DIST_ARCH="$(get_distr_arch)"
    MATCH_STR="$RAW_ARCH $DIST_ARCH"

    case "$MATCH_STR" in
        *x86_64*|*amd64*)
            printf 'x86_64'
            ;;
        *i386*|*i686*|*x86*)
            printf 'x86'
            ;;
        *aarch64*|*arm64*|*armv8*)
            printf 'aarch64'
            ;;
        *arm*)
            printf 'arm'
            ;;
        *mipsel*)
            printf 'mipsel'
            ;;
        *mips*)
            printf 'mips'
            ;;
        *)
            printf ''
            ;;
    esac
}

download_url() {
    URL="$1"
    OUT="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --connect-timeout 15 "$URL" -o "$OUT"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$OUT" "$URL"
    else
        die "缺少 curl 或 wget，无法下载文件"
    fi
}

fetch_release_json() {
    download_url "$SMARTDNS_API" "$TMP_ROOT/release.json" || die "获取 SmartDNS 最新 Release 信息失败"
}

find_asset_url() {
    PATTERN="$1"
    sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/p' "$TMP_ROOT/release.json" | grep "$PATTERN" | head -n1 || true
}

get_installed_version() {
    PKG_MGR="$1"
    case "$PKG_MGR" in
        opkg)
            opkg status smartdns 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true
            ;;
        apk)
            apk info -a smartdns 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true
            ;;
    esac
}

maybe_update_index() {
    PKG_MGR="$1"
    if [ "$FORCE_PKG_UPDATE" != "1" ]; then
        log "按参数跳过软件源更新"
        return 0
    fi

    case "$PKG_MGR" in
        opkg)
            log "刷新 opkg 软件源索引"
            opkg update || warn "opkg update 失败，将继续尝试安装 GitHub Release 包"
            ;;
        apk)
            log "刷新 apk 软件源索引"
            apk update || warn "apk update 失败，将继续尝试安装 GitHub Release 包"
            ;;
    esac
}

install_release_packages() {
    PKG_MGR="$1"
    SMARTDNS_ARCH="$2"

    case "$PKG_MGR" in
        opkg)
            EXT="ipk"
            INSTALL_CMD="opkg install"
            ;;
        apk)
            EXT="apk"
            INSTALL_CMD="apk add --allow-untrusted"
            ;;
    esac

    CORE_URL="$(find_asset_url "smartdns\..*\.${SMARTDNS_ARCH}-openwrt-all\.${EXT}$")"
    LUCI_URL="$(find_asset_url "luci-app-smartdns\..*\.all-luci-all\.${EXT}$")"

    [ -n "$CORE_URL" ] || die "未找到当前架构的 SmartDNS Release 包: $SMARTDNS_ARCH / $EXT"
    [ -n "$LUCI_URL" ] || die "未找到 LuCI SmartDNS Release 包: $EXT"

    CORE_PKG="$TMP_ROOT/$(basename "$CORE_URL")"
    LUCI_PKG="$TMP_ROOT/$(basename "$LUCI_URL")"

    log "下载 SmartDNS: $(basename "$CORE_PKG")"
    download_url "$CORE_URL" "$CORE_PKG" || die "下载 SmartDNS 包失败"

    log "下载 LuCI SmartDNS: $(basename "$LUCI_PKG")"
    download_url "$LUCI_URL" "$LUCI_PKG" || die "下载 LuCI SmartDNS 包失败"

    log "安装 / 更新 SmartDNS"
    # shellcheck disable=SC2086
    $INSTALL_CMD "$CORE_PKG" || die "安装 SmartDNS 失败，请检查系统依赖或软件源"

    log "安装 / 更新 LuCI SmartDNS 界面"
    # shellcheck disable=SC2086
    if ! $INSTALL_CMD "$LUCI_PKG"; then
        if [ "$PKG_MGR" = "opkg" ] && opkg status luci-i18n-smartdns-zh-cn >/dev/null 2>&1; then
            warn "检测到旧版 luci-i18n-smartdns-zh-cn 与新版 luci-app-smartdns 文件冲突，正在移除旧语言包后重试"
            opkg remove luci-i18n-smartdns-zh-cn || die "移除冲突语言包失败，请手动执行: opkg remove luci-i18n-smartdns-zh-cn"
            opkg install "$LUCI_PKG" || die "安装 LuCI SmartDNS 失败，请检查系统依赖或软件源"
        else
            die "安装 LuCI SmartDNS 失败，请检查系统依赖或软件源"
        fi
    fi
}

refresh_luci() {
    rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true
    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >/dev/null 2>&1 || warn "rpcd 重启失败"
    fi
}

restart_smartdns() {
    if [ "$RESTART_SERVICES" != "1" ]; then
        log "按参数跳过 smartdns 启用 / 重启"
        return 0
    fi

    if [ -x /etc/init.d/smartdns ]; then
        /etc/init.d/smartdns enable >/dev/null 2>&1 || warn "smartdns enable 失败"
        /etc/init.d/smartdns restart >/dev/null 2>&1 || warn "smartdns restart 失败"
    else
        warn "未发现 /etc/init.d/smartdns，跳过服务重启"
    fi
}

main() {
    parse_args "$@"

    if ! mkdir "$LOCKDIR" 2>/dev/null; then
        die "已有另一个 SmartDNS 任务正在运行"
    fi
    mkdir -p "$TMP_ROOT"

    need_cmd sed
    need_cmd grep
    need_cmd head
    need_cmd basename

    PKG_MGR="$(detect_pkg_mgr)"
    SMARTDNS_ARCH="$(detect_smartdns_arch)"
    [ -n "$SMARTDNS_ARCH" ] || die "暂不支持当前架构: $(uname -m 2>/dev/null || printf unknown)"

    log "检测到包管理器: $PKG_MGR"
    log "检测到 SmartDNS 架构: $SMARTDNS_ARCH"
    OLD_VER="$(get_installed_version "$PKG_MGR")"
    log "当前已安装版本: ${OLD_VER:-not installed}"

    maybe_update_index "$PKG_MGR"
    fetch_release_json
    install_release_packages "$PKG_MGR" "$SMARTDNS_ARCH"
    restart_smartdns
    refresh_luci

    NEW_VER="$(get_installed_version "$PKG_MGR")"
    log "安装后版本: ${NEW_VER:-unknown}"
    warn "默认不主动改写 /etc/config/smartdns；请在 LuCI 中按你的网络环境启用或调整 DNS 转发设置"
    warn "如果 LuCI 菜单未立即出现，请刷新页面或重新登录 LuCI"
    log "SmartDNS 处理完成"
}

main "$@"
