#!/bin/sh
set -eu

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

detect_pkg_mgr() {
    if command -v opkg >/dev/null 2>&1; then
        printf 'opkg'
    elif command -v apk >/dev/null 2>&1; then
        printf 'apk'
    else
        die "未检测到 opkg 或 apk，当前系统暂不支持"
    fi
}

ensure_dir() {
    [ -d "$1" ] || mkdir -p "$1"
}

fix_core_permissions() {
    if [ -f /etc/openclash/core/clash_meta ]; then
        chmod 0755 /etc/openclash/core/clash_meta || warn "修复 clash_meta 权限失败"
        log "已检查并修复 clash_meta 权限"
    else
        warn "未发现 /etc/openclash/core/clash_meta"
    fi
}

restart_services() {
    if [ -x /etc/init.d/openclash ]; then
        /etc/init.d/openclash restart >/dev/null 2>&1 || warn "OpenClash 服务重启失败"
        log "已尝试重启 OpenClash"
    fi

    if [ -x /etc/init.d/uhttpd ]; then
        /etc/init.d/uhttpd restart >/dev/null 2>&1 || warn "uhttpd 重启失败"
        log "已尝试重启 uhttpd"
    fi
}

refresh_index() {
    PKG_MGR="$1"
    case "$PKG_MGR" in
        opkg)
            log "刷新 opkg 软件源"
            opkg update || warn "opkg update 失败"
            ;;
        apk)
            log "刷新 apk 软件源"
            apk update || warn "apk update 失败"
            ;;
    esac
}

show_status() {
    PKG_MGR="$1"
    log "系统包管理器: $PKG_MGR"

    if [ -f /etc/openclash/core/clash_meta ]; then
        log "检测到 Meta 内核: /etc/openclash/core/clash_meta"
    else
        warn "未检测到 Meta 内核文件"
    fi

    if [ "$PKG_MGR" = "opkg" ]; then
        VER="$(opkg status luci-app-openclash 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
    else
        VER="$(apk info -a luci-app-openclash 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true)"
    fi

    log "当前 OpenClash 版本: ${VER:-unknown or not installed}"
}

main() {
    PKG_MGR="$(detect_pkg_mgr)"

    log "开始执行 OpenClash 修复流程"
    ensure_dir /etc/openclash
    ensure_dir /etc/openclash/core

    refresh_index "$PKG_MGR"
    fix_core_permissions
    restart_services
    show_status "$PKG_MGR"

    log "修复流程完成"
}

main "$@"
