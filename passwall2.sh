#!/bin/sh
set -eu

LOCKDIR="/tmp/passwall2-install.lock"
KEY_URL="https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub"
GH_API="https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall2/releases/latest"

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
    die "已有另一个 PassWall2 任务正在运行"
fi

need_cmd opkg
need_cmd wget
need_cmd sed

[ -f /etc/openwrt_release ] || die "未检测到 /etc/openwrt_release"
# shellcheck disable=SC1091
. /etc/openwrt_release

ARCH="${DISTRIB_ARCH:-}"
REL_RAW="${DISTRIB_RELEASE:-}"
[ -n "$ARCH" ] || die "无法识别系统架构"
[ -n "$REL_RAW" ] || die "无法识别系统版本"

case "$REL_RAW" in
    *SNAPSHOT*)
        FEED_BASE="https://master.dl.sourceforge.net/project/openwrt-passwall-build/snapshots/packages/$ARCH"
        ;;
    *)
        RELEASE="${REL_RAW%.*}"
        FEED_BASE="https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$RELEASE/$ARCH"
        ;;
esac

log "System release: $REL_RAW"
log "Arch: $ARCH"
log "Feed base: $FEED_BASE"

GH_LATEST="$(wget -qO- "$GH_API" 2>/dev/null | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
[ -n "$GH_LATEST" ] && log "GitHub latest release: $GH_LATEST"

touch /etc/opkg/customfeeds.conf
sed -i '\|openwrt-passwall-build|d' /etc/opkg/customfeeds.conf
sed -i '/^src\/gz passwall_luci /d' /etc/opkg/customfeeds.conf
sed -i '/^src\/gz passwall_packages /d' /etc/opkg/customfeeds.conf
sed -i '/^src\/gz passwall2 /d' /etc/opkg/customfeeds.conf

cd /tmp
rm -f passwall.pub
wget -qO passwall.pub "$KEY_URL" || die "下载 PassWall 公钥失败"
opkg-key add /tmp/passwall.pub >/dev/null 2>&1 || true

for feed in passwall_luci passwall_packages passwall2; do
    echo "src/gz $feed $FEED_BASE/$feed" >> /etc/opkg/customfeeds.conf
done

log "刷新软件源"
opkg update

OLD_VER="$(opkg status luci-app-passwall2 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
log "当前已安装版本: ${OLD_VER:-not installed}"

log "安装 / 更新 PassWall2"
opkg install luci-app-passwall2 luci-i18n-passwall2-zh-cn

NEW_VER="$(opkg status luci-app-passwall2 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
log "安装后版本: ${NEW_VER:-unknown}"

if [ ! -f /etc/config/passwall2 ]; then
    if [ -f /usr/share/passwall2/0_default_config ]; then
        log "检测到缺少 /etc/config/passwall2，使用默认配置补齐"
        cp -f /usr/share/passwall2/0_default_config /etc/config/passwall2
    else
        warn "未发现默认配置文件，自动生成最小 /etc/config/passwall2 以确保 LuCI 入口可用"
        cat >/etc/config/passwall2 <<'EOF'
config global
	option enabled '0'
EOF
    fi
fi

log "轻刷新 LuCI 缓存"
rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true

if [ -n "$NEW_VER" ] && [ "$OLD_VER" != "$NEW_VER" ]; then
    log "版本发生变化，尝试重启相关服务"
    /etc/init.d/firewall restart >/dev/null 2>&1 || true
    /etc/init.d/passwall2 restart >/dev/null 2>&1 || true
else
    log "版本未变化，跳过防火墙/服务重启"
fi

warn "请刷新页面或切换一次左侧菜单，插件入口会自动更新；如仍未生效，再重新登录 LuCI"

if opkg status luci-app-passwall >/dev/null 2>&1; then
    warn "检测到已安装 PassWall；在部分主题下，PassWall 与 PassWall2 菜单可能重叠或显示不明显"
    warn "如菜单未明显显示，可直接访问: /cgi-bin/luci/admin/services/passwall2"
fi

warn "如界面初次显示为英文，请刷新页面，中文语言包会自动生效"
log "PassWall2 处理完成"
