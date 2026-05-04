#!/bin/sh
set -eu

LOCKDIR="/tmp/mosdns-install.lock"
TMP_ROOT="/tmp/mosdns-install"
MOSDNS_API="https://api.github.com/repos/sbwml/luci-app-mosdns/releases/latest"
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
  sh mosdns.sh [选项]

选项:
  --skip-restart      完成后不尝试启用 / 重启 mosdns
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

select_sdk() {
    PKG_MGR="$1"
    case "$PKG_MGR" in
        apk)
            printf 'openwrt-25.12'
            ;;
        opkg)
            printf 'openwrt-24.10'
            ;;
        *)
            die "未知包管理器: $PKG_MGR"
            ;;
    esac
}

download_url() {
    URL="$1"
    OUT="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --connect-timeout 15 \
            -A "openclaw-openwrt-installer" \
            "$URL" -o "$OUT"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$OUT" --user-agent="openclaw-openwrt-installer" "$URL"
    else
        die "缺少 curl 或 wget，无法下载文件"
    fi
}

download_github_api() {
    URL="$1"
    OUT="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --connect-timeout 15 \
            -A "openclaw-openwrt-installer" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$URL" -o "$OUT"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$OUT" \
            --user-agent="openclaw-openwrt-installer" \
            --header="Accept: application/vnd.github+json" \
            --header="X-GitHub-Api-Version: 2022-11-28" \
            "$URL"
    else
        die "缺少 curl 或 wget，无法下载文件"
    fi
}

find_asset_url() {
    ASSET_NAME="$1"
    sed 's/"browser_download_url"/\
"browser_download_url"/g' "$TMP_ROOT/release.json" |
        sed -n 's/^"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
        grep "/$ASSET_NAME$" |
        head -n1 || true
}

fetch_release_json() {
    download_github_api "$MOSDNS_API" "$TMP_ROOT/release.json" || die "获取 MosDNS 最新 Release 信息失败"
}

get_installed_version() {
    PKG_MGR="$1"
    case "$PKG_MGR" in
        opkg)
            opkg status mosdns 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true
            ;;
        apk)
            apk info -a mosdns 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true
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

check_runtime() {
    [ -f /etc/openwrt_release ] || die "未检测到 /etc/openwrt_release，当前环境不像 OpenWrt"
    [ -d /usr/share/luci/menu.d ] || die "当前 LuCI 版本可能过旧，未发现 /usr/share/luci/menu.d"

    ROOT_SPACE="$(df -m /usr | awk 'END{print $4}' 2>/dev/null || printf 0)"
    case "$ROOT_SPACE" in
        ''|*[!0-9]*) ROOT_SPACE=0 ;;
    esac
    if [ "$ROOT_SPACE" -lt 35 ]; then
        die "系统 /usr 可用空间小于 35MB，不建议继续安装 MosDNS"
    fi
}

install_release_archive() {
    PKG_MGR="$1"
    DISTR_ARCH="$2"
    SDK="$3"
    ASSET_NAME="${DISTR_ARCH}-${SDK}.tar.gz"

    fetch_release_json
    ASSET_URL="$(find_asset_url "$ASSET_NAME")"
    [ -n "$ASSET_URL" ] || die "未找到当前架构的 MosDNS Release 包: $ASSET_NAME"

    ARCHIVE="$TMP_ROOT/$ASSET_NAME"
    EXTRACT_DIR="$TMP_ROOT/extract"
    mkdir -p "$EXTRACT_DIR"

    log "下载 MosDNS Release 包: $ASSET_NAME"
    download_url "$ASSET_URL" "$ARCHIVE" || die "下载 MosDNS Release 包失败"

    log "解压 MosDNS Release 包"
    tar -zxf "$ARCHIVE" -C "$EXTRACT_DIR" || die "解压 MosDNS Release 包失败"

    if [ -x /etc/init.d/mosdns ]; then
        log "停止 MosDNS 服务"
        /etc/init.d/mosdns stop >/dev/null 2>&1 || true
    fi

    case "$PKG_MGR" in
        opkg)
            INSTALL_CMD="opkg install --force-downgrade"
            ;;
        apk)
            INSTALL_CMD="apk add --allow-untrusted"
            ;;
    esac

    log "安装 / 更新 MosDNS 相关包"
    for pkg in \
        "$EXTRACT_DIR"/packages_ci/v2dat*.* \
        "$EXTRACT_DIR"/packages_ci/v2ray-geoip*.* \
        "$EXTRACT_DIR"/packages_ci/v2ray-geosite*.* \
        "$EXTRACT_DIR"/packages_ci/mosdns*.* \
        "$EXTRACT_DIR"/packages_ci/luci-app-mosdns*.* \
        "$EXTRACT_DIR"/packages_ci/luci-i18n-mosdns-zh-cn*.*; do
        [ -f "$pkg" ] || continue
        # shellcheck disable=SC2086
        $INSTALL_CMD "$pkg" || die "安装失败: $(basename "$pkg")"
    done
}

refresh_luci() {
    rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true
    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >/dev/null 2>&1 || warn "rpcd 重启失败"
    fi
}

restart_mosdns() {
    if [ "$RESTART_SERVICES" != "1" ]; then
        log "按参数跳过 mosdns 启用 / 重启"
        return 0
    fi

    if [ -x /etc/init.d/mosdns ]; then
        /etc/init.d/mosdns enable >/dev/null 2>&1 || warn "mosdns enable 失败"
        /etc/init.d/mosdns restart >/dev/null 2>&1 || warn "mosdns restart 失败"
    else
        warn "未发现 /etc/init.d/mosdns，跳过服务重启"
    fi
}

main() {
    parse_args "$@"

    if ! mkdir "$LOCKDIR" 2>/dev/null; then
        die "已有另一个 MosDNS 任务正在运行"
    fi
    mkdir -p "$TMP_ROOT"

    need_cmd sed
    need_cmd grep
    need_cmd head
    need_cmd basename
    need_cmd tar
    need_cmd df
    need_cmd awk

    check_runtime

    PKG_MGR="$(detect_pkg_mgr)"
    DISTR_ARCH="$(get_distr_arch)"
    [ -n "$DISTR_ARCH" ] || die "无法读取 DISTRIB_ARCH，暂不支持当前系统"
    SDK="$(select_sdk "$PKG_MGR")"

    log "检测到包管理器: $PKG_MGR"
    log "检测到 MosDNS 架构: $DISTR_ARCH"
    log "使用构建版本: $SDK"
    OLD_VER="$(get_installed_version "$PKG_MGR")"
    log "当前已安装版本: ${OLD_VER:-not installed}"

    maybe_update_index "$PKG_MGR"
    install_release_archive "$PKG_MGR" "$DISTR_ARCH" "$SDK"
    restart_mosdns
    refresh_luci

    NEW_VER="$(get_installed_version "$PKG_MGR")"
    log "安装后版本: ${NEW_VER:-unknown}"
    warn "默认不主动改写 /etc/config/mosdns；请在 LuCI 中按你的网络环境启用或调整 DNS 分流设置"
    warn "如果 LuCI 菜单未立即出现，请刷新页面或重新登录 LuCI"
    log "MosDNS 处理完成"
}

main "$@"
