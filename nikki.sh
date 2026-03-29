#!/bin/sh
set -eu

LOCKDIR="/tmp/nikki-install.lock"
FEED_SCRIPT_URL="https://github.com/nikkinikki-org/OpenWrt-nikki/raw/refs/heads/main/feed.sh"

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
log "导入 Nikki feed"
wget -qO- "$FEED_SCRIPT_URL" | sh || die "执行 Nikki feed.sh 失败"

case "$PKG_MGR" in
    opkg)
        OLD_VER="$(opkg status luci-app-nikki 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
        log "当前已安装版本: ${OLD_VER:-not installed}"
        log "安装 / 更新 Nikki"
        opkg install nikki luci-app-nikki luci-i18n-nikki-zh-cn
        NEW_VER="$(opkg status luci-app-nikki 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
        ;;
    apk)
        log "刷新软件源"
        apk update
        OLD_VER="$(apk info -a luci-app-nikki 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true)"
        log "当前已安装版本: ${OLD_VER:-not installed}"
        log "安装 / 更新 Nikki"
        apk add nikki luci-app-nikki luci-i18n-nikki-zh-cn
        NEW_VER="$(apk info -a luci-app-nikki 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true)"
        ;;
esac

log "安装后版本: ${NEW_VER:-unknown}"

if [ ! -f /etc/config/nikki ]; then
    DEFAULT_NIKKI_CONFIG="$(find /usr/share /etc /usr/lib -iname '*nikki*' 2>/dev/null | grep -Ei 'default|config|example|sample' | head -n1 || true)"
    if [ -n "$DEFAULT_NIKKI_CONFIG" ] && [ -f "$DEFAULT_NIKKI_CONFIG" ]; then
        log "检测到缺少 /etc/config/nikki，使用默认配置补齐: $DEFAULT_NIKKI_CONFIG"
        cp -f "$DEFAULT_NIKKI_CONFIG" /etc/config/nikki
    else
        warn "未发现默认配置文件，自动生成最小 /etc/config/nikki 以确保 LuCI 入口可用"
        cat >/etc/config/nikki <<'EOF'
config nikki 'config'
	option enabled '0'
EOF
    fi
fi

log "轻刷新 LuCI 缓存"
rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true

if [ -n "${NEW_VER:-}" ] && [ "${OLD_VER:-}" != "${NEW_VER:-}" ]; then
    log "版本发生变化，尝试重启相关服务"
    /etc/init.d/firewall restart >/dev/null 2>&1 || true
    /etc/init.d/nikki restart >/dev/null 2>&1 || true
else
    log "版本未变化，跳过防火墙/服务重启"
fi

warn "请刷新页面或切换一次左侧菜单，插件入口会自动更新；如仍未生效，再重新登录 LuCI"
warn "如界面初次显示为英文，请刷新页面，中文语言包会自动生效"
log "Nikki 处理完成"
