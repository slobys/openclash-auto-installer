#!/bin/sh
set -eu

LOCKDIR="/tmp/nikki-install.lock"
FEED_SCRIPT_URL="https://raw.githubusercontent.com/nikkinikki-org/OpenWrt-nikki/main/feed.sh"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/nikkinikki-org/OpenWrt-nikki/main/install.sh"

cleanup() {
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

detect_firewall_stack() {
    if command -v fw4 >/dev/null 2>&1 || [ -x /sbin/fw4 ] || [ -x /usr/sbin/fw4 ]; then
        printf 'nft'
    else
        printf 'iptables'
    fi
}

refresh_luci() {
    rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true
    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >/dev/null 2>&1 || warn "rpcd 重启失败"
    fi
}

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    die "已有另一个 Nikki 任务正在运行"
fi

[ -f /etc/openwrt_release ] || die "未检测到 /etc/openwrt_release"
# shellcheck disable=SC1091
. /etc/openwrt_release

REL_RAW="${DISTRIB_RELEASE:-}"
log "System release: ${REL_RAW:-unknown}"

need_cmd wget

if command -v opkg >/dev/null 2>&1; then
    PKG_MGR="opkg"
elif command -v apk >/dev/null 2>&1; then
    PKG_MGR="apk"
else
    die "未检测到 opkg 或 apk"
fi

log "检测到包管理器: $PKG_MGR"
FIREWALL_STACK="$(detect_firewall_stack)"
log "检测到防火墙栈: $FIREWALL_STACK"
if [ "$FIREWALL_STACK" = "iptables" ]; then
    die "Nikki 仅支持基于 firewall4（nftables）的 OpenWrt 构建。\n  当前系统防火墙栈为 iptables，请使用支持 firewall4 的 OpenWrt 固件。"
fi
if [ "$PKG_MGR" = "apk" ]; then
    warn "当前包管理器为 apk（OpenWrt 25.12+），Nikki 可能尚未完全适配。"
fi

case "$PKG_MGR" in
    opkg)
        OLD_VER="$(opkg status luci-app-nikki 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
        log "当前已安装版本: ${OLD_VER:-not installed}"
        log "按官方方式导入 Nikki feed"
        wget -qO- "$FEED_SCRIPT_URL" | sh || die "执行 Nikki feed.sh 失败"
        log "按官方方式安装 / 更新 Nikki"
        wget -qO- "$INSTALL_SCRIPT_URL" | sh || die "执行 Nikki 官方 install.sh 失败"
        opkg install luci-i18n-nikki-zh-cn || warn "安装 Nikki 中文语言包失败"
        NEW_VER="$(opkg status luci-app-nikki 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
        ;;
    apk)
        log "刷新软件源"
        apk update
        OLD_VER="$(apk info -a luci-app-nikki 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true)"
        log "当前已安装版本: ${OLD_VER:-not installed}"
        log "按官方包管理方式安装 / 更新 Nikki"
        apk add nikki luci-app-nikki luci-i18n-nikki-zh-cn
        NEW_VER="$(apk info -a luci-app-nikki 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true)"
        ;;
esac

log "安装后版本: ${NEW_VER:-unknown}"
refresh_luci
warn "默认不主动改写 Nikki 配置；如界面初次显示异常，可手动刷新页面或重新登录 LuCI"
warn "如界面初次显示为英文，请刷新页面，中文语言包会自动生效"
log "Nikki 处理完成"
