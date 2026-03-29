#!/bin/sh
set -eu

TARGET="${1:-}"

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
    KIND="${3:-package}"

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
                    warn "$PKG 仍被其他插件依赖，已跳过"
                    return 0
                    ;;
                *"can't open '"*|*"No such file or directory"*)
                    warn "$PKG 卸载时检测到残缺文件，已继续执行环境清理"
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

remove_pkgs() {
    PKG_MGR="$1"
    shift
    for pkg in "$@"; do
        remove_pkg_if_installed "$PKG_MGR" "$pkg"
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

remove_paths() {
    for path in "$@"; do
        rm -rf "$path" 2>/dev/null || true
    done
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

full_uninstall_passwall() {
    PKG_MGR="$1"
    log "开始完整卸载 PassWall"

    stop_disable_service passwall

    remove_pkgs "$PKG_MGR" \
        luci-app-passwall \
        luci-i18n-passwall-zh-cn \
        passwall \
        hysteria \
        tuic-client \
        naiveproxy \
        shadowsocks-libev-ss-local \
        shadowsocks-libev-ss-redir \
        shadowsocks-libev-ss-server \
        shadowsocks-rust-sslocal \
        shadowsocks-rust-ssserver \
        shadowsocksr-libev-ssr-local \
        shadowsocksr-libev-ssr-redir \
        shadowsocksr-libev-ssr-server \
        sing-box \
        xray-core \
        v2ray-plugin \
        xray-plugin \
        v2ray-geoip \
        v2ray-geosite

    remove_paths \
        /etc/config/passwall \
        /usr/share/passwall \
        /etc/passwall \
        /var/etc/passwall* \
        /tmp/etc/passwall*

    log "PassWall 完整卸载完成"
}

full_uninstall_passwall2() {
    PKG_MGR="$1"
    log "开始完整卸载 PassWall2"

    stop_disable_service passwall2

    remove_pkgs "$PKG_MGR" \
        luci-app-passwall2 \
        luci-i18n-passwall2-zh-cn \
        passwall2 \
        hysteria \
        tuic-client \
        naiveproxy \
        shadowsocks-libev-ss-local \
        shadowsocks-libev-ss-redir \
        shadowsocks-libev-ss-server \
        shadowsocks-rust-sslocal \
        shadowsocks-rust-ssserver \
        shadowsocksr-libev-ssr-local \
        shadowsocksr-libev-ssr-redir \
        shadowsocksr-libev-ssr-server \
        sing-box \
        xray-core \
        v2ray-plugin \
        xray-plugin \
        v2ray-geoip \
        v2ray-geosite

    remove_paths \
        /etc/config/passwall2 \
        /usr/share/passwall2 \
        /etc/passwall2 \
        /var/etc/passwall2* \
        /tmp/etc/passwall2*

    log "PassWall2 完整卸载完成"
}

full_uninstall_nikki() {
    PKG_MGR="$1"
    log "开始完整卸载 Nikki"

    stop_disable_service nikki

    remove_pkgs "$PKG_MGR" \
        luci-app-nikki \
        luci-i18n-nikki-zh-cn \
        nikki \
        sing-box \
        hysteria \
        tuic-client \
        naiveproxy \
        shadowsocks-libev-ss-local \
        shadowsocks-libev-ss-redir \
        shadowsocks-libev-ss-server \
        shadowsocks-rust-sslocal \
        shadowsocks-rust-ssserver \
        shadowsocksr-libev-ssr-local \
        shadowsocksr-libev-ssr-redir \
        shadowsocksr-libev-ssr-server \
        xray-core \
        v2ray-plugin \
        xray-plugin \
        v2ray-geoip \
        v2ray-geosite

    remove_paths \
        /etc/config/nikki \
        /usr/share/nikki \
        /etc/nikki \
        /var/etc/nikki* \
        /tmp/etc/nikki*

    log "Nikki 完整卸载完成"
}

full_uninstall_openclash() {
    PKG_MGR="$1"
    log "开始完整卸载 OpenClash"

    stop_disable_service openclash

    remove_pkgs "$PKG_MGR" \
        luci-app-openclash \
        mihomo \
        clash \
        clash-meta \
        sing-box \
        hysteria \
        tuic-client \
        naiveproxy \
        shadowsocks-libev-ss-local \
        shadowsocks-libev-ss-redir \
        shadowsocks-libev-ss-server \
        shadowsocks-rust-sslocal \
        shadowsocks-rust-ssserver \
        shadowsocksr-libev-ssr-local \
        shadowsocksr-libev-ssr-redir \
        shadowsocksr-libev-ssr-server \
        xray-core \
        v2ray-plugin \
        xray-plugin \
        v2ray-geoip \
        v2ray-geosite

    remove_paths \
        /etc/config/openclash \
        /etc/openclash \
        /usr/share/openclash \
        /var/etc/openclash* \
        /tmp/etc/openclash* \
        /tmp/openclash*

    log "OpenClash 完整卸载完成"
}

usage() {
    cat <<'EOF_USAGE'
用法:
  sh full-uninstall.sh passwall
  sh full-uninstall.sh passwall2
  sh full-uninstall.sh nikki
  sh full-uninstall.sh openclash
EOF_USAGE
}

main() {
    [ -n "$TARGET" ] || {
        usage
        exit 1
    }

    PKG_MGR="$(detect_pkg_mgr)"
    log "检测到包管理器: $PKG_MGR"

    case "$TARGET" in
        passwall)
            full_uninstall_passwall "$PKG_MGR"
            ;;
        passwall2)
            full_uninstall_passwall2 "$PKG_MGR"
            ;;
        nikki)
            full_uninstall_nikki "$PKG_MGR"
            ;;
        openclash)
            full_uninstall_openclash "$PKG_MGR"
            ;;
        -h|--help|help)
            usage
            exit 0
            ;;
        *)
            die "不支持的完整卸载目标: $TARGET"
            ;;
    esac

    refresh_web
    log "完整卸载流程完成，建议刷新页面；如菜单残留可重启路由"
}

main "$@"
