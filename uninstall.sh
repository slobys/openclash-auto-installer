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

remove_openclash_core() {
    if [ -f /etc/openclash/core/clash_meta ]; then
        rm -f /etc/openclash/core/clash_meta
        log "已删除 /etc/openclash/core/clash_meta"
    else
        warn "未发现 clash_meta 内核文件，跳过"
    fi
}

remove_openclash_package() {
    PKG_MGR="$1"

    case "$PKG_MGR" in
        opkg)
            if opkg status luci-app-openclash >/dev/null 2>&1; then
                opkg remove luci-app-openclash || warn "移除 luci-app-openclash 失败"
            else
                warn "luci-app-openclash 未安装，跳过插件卸载"
            fi
            ;;
        apk)
            if apk info -e luci-app-openclash >/dev/null 2>&1; then
                apk del luci-app-openclash || warn "移除 luci-app-openclash 失败"
            else
                warn "luci-app-openclash 未安装，跳过插件卸载"
            fi
            ;;
    esac
}

main() {
    PKG_MGR="$(detect_pkg_mgr)"
    log "检测到包管理器: $PKG_MGR"

    log "开始卸载 OpenClash 插件"
    remove_openclash_package "$PKG_MGR"

    log "清理 Meta 内核文件"
    remove_openclash_core

    warn "默认未删除 /etc/openclash 配置目录，以避免误删订阅和配置"
    warn "如果你确认不再需要，可手动执行: rm -rf /etc/openclash"

    log "卸载流程完成"
}

main "$@"
