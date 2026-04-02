#!/bin/sh
set -eu

TARGET="${1:-}"
DELETE_CONFIG=0

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

pkg_installed() {
    PKG_MGR="$1"
    PKG="$2"

    case "$PKG_MGR" in
        opkg)
            opkg status "$PKG" >/dev/null 2>&1
            ;;
        apk)
            apk info -e "$PKG" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

remove_pkg_if_installed() {
    PKG_MGR="$1"
    PKG="$2"

    if ! pkg_installed "$PKG_MGR" "$PKG"; then
        log "未安装 $PKG，跳过"
        return 0
    fi

    case "$PKG_MGR" in
        opkg)
            OUTPUT="$(opkg remove "$PKG" 2>&1)" || STATUS=$?
            STATUS="${STATUS:-0}"
            printf '%s\n' "$OUTPUT"

            if [ "$STATUS" -eq 0 ]; then
                return 0
            fi

            case "$OUTPUT" in
                *"is depended upon by packages:"*|*"print_dependents_warning:"*)
                    warn "$PKG 仍被其他包依赖，已跳过"
                    return 0
                    ;;
                *"can't open '"*|*"No such file or directory"*)
                    warn "$PKG 卸载时检测到残缺文件，已继续执行后续流程"
                    return 0
                    ;;
                *)
                    warn "移除 $PKG 失败"
                    return 0
                    ;;
            esac
            ;;
        apk)
            apk del "$PKG" || warn "移除 $PKG 失败"
            ;;
    esac
}

remove_paths() {
    for path in "$@"; do
        rm -rf "$path" 2>/dev/null || true
    done
}

stop_disable_service() {
    SVC="$1"

    if [ -x "/etc/init.d/$SVC" ]; then
        /etc/init.d/"$SVC" stop >/dev/null 2>&1 || true
        /etc/init.d/"$SVC" disable >/dev/null 2>&1 || true
        log "已停止并禁用服务: $SVC"
    else
        log "未发现服务脚本: $SVC，跳过"
    fi
}

refresh_web() {
    remove_paths \
        /tmp/luci-* \
        /tmp/.luci* \
        /tmp/etc/config/ucitrack \
        /var/run/luci-indexcache

    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >/dev/null 2>&1 || warn "rpcd 重启失败"
    fi

    warn "请刷新页面或切换一次左侧菜单，插件入口会自动更新；如仍未生效，再重新登录 LuCI"
}

remove_openclash_core() {
    if [ -f /etc/openclash/core/clash_meta ]; then
        rm -f /etc/openclash/core/clash_meta
        log "已删除 /etc/openclash/core/clash_meta"
    else
        warn "未发现 clash_meta 内核文件，跳过"
    fi
}

safe_uninstall_passwall() {
    PKG_MGR="$1"
    log "开始安全卸载 PassWall（仅卸载主包）"

    stop_disable_service passwall
    remove_pkg_if_installed "$PKG_MGR" luci-app-passwall
    remove_pkg_if_installed "$PKG_MGR" luci-i18n-passwall-zh-cn

    if [ "$DELETE_CONFIG" -eq 1 ]; then
        log "删除 PassWall 配置文件"
        remove_paths /etc/config/passwall
    else
        warn "默认保留 /etc/config/passwall 配置文件"
    fi

    log "PassWall 安全卸载完成"
}

safe_uninstall_passwall2() {
    PKG_MGR="$1"
    log "开始安全卸载 PassWall2（仅卸载主包）"

    stop_disable_service passwall2
    remove_pkg_if_installed "$PKG_MGR" luci-app-passwall2
    remove_pkg_if_installed "$PKG_MGR" luci-i18n-passwall2-zh-cn

    if [ "$DELETE_CONFIG" -eq 1 ]; then
        log "删除 PassWall2 配置文件"
        remove_paths /etc/config/passwall2
    else
        warn "默认保留 /etc/config/passwall2 配置文件"
    fi

    log "PassWall2 安全卸载完成"
}

safe_uninstall_nikki() {
    PKG_MGR="$1"
    log "开始安全卸载 Nikki（仅卸载主包）"

    stop_disable_service nikki
    remove_pkg_if_installed "$PKG_MGR" luci-app-nikki
    remove_pkg_if_installed "$PKG_MGR" luci-i18n-nikki-zh-cn

    if [ "$DELETE_CONFIG" -eq 1 ]; then
        log "删除 Nikki 配置文件"
        remove_paths /etc/config/nikki
    else
        warn "默认保留 /etc/config/nikki 配置文件"
    fi

    log "Nikki 安全卸载完成"
}

safe_uninstall_openclash() {
    PKG_MGR="$1"
    log "开始安全卸载 OpenClash（仅卸载主包）"

    stop_disable_service openclash
    remove_pkg_if_installed "$PKG_MGR" luci-app-openclash
    remove_openclash_core

    if [ "$DELETE_CONFIG" -eq 1 ]; then
        log "删除 OpenClash 配置目录"
        remove_paths /etc/config/openclash /etc/openclash
    else
        warn "默认保留 /etc/openclash 配置目录，以避免误删订阅和配置"
    fi

    log "OpenClash 安全卸载完成"
}

usage() {
    cat <<'EOF_USAGE'
用法:
  sh uninstall.sh passwall [--delete-config]
  sh uninstall.sh passwall2 [--delete-config]
  sh uninstall.sh nikki [--delete-config]
  sh uninstall.sh openclash [--delete-config]

说明:
  默认执行安全卸载，只移除主包，不动共享依赖。
  --delete-config 会额外删除对应插件的配置文件。
EOF_USAGE
}

parse_args() {
    [ -n "$TARGET" ] || {
        usage
        exit 1
    }

    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --delete-config)
                DELETE_CONFIG=1
                ;;
            -h|--help|help)
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

main() {
    parse_args "$@"
    PKG_MGR="$(detect_pkg_mgr)"
    log "检测到包管理器: $PKG_MGR"

    case "$TARGET" in
        passwall)
            safe_uninstall_passwall "$PKG_MGR"
            ;;
        passwall2)
            safe_uninstall_passwall2 "$PKG_MGR"
            ;;
        nikki)
            safe_uninstall_nikki "$PKG_MGR"
            ;;
        openclash)
            safe_uninstall_openclash "$PKG_MGR"
            ;;
        *)
            die "不支持的安全卸载目标: $TARGET"
            ;;
    esac

    refresh_web
    log "安全卸载流程完成"
}

main "$@"
