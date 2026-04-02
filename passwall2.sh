#!/bin/sh
set -eu

LOCKDIR="/tmp/passwall2-install.lock"
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

download_file() {
    url="$1"
    output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output" 2>/dev/null && return 0
        curl -kfsSL "$url" -o "$output" 2>/dev/null && return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO "$output" "$url" 2>/dev/null && return 0
        wget --no-check-certificate -qO "$output" "$url" 2>/dev/null && return 0
    fi

    return 1
}

download_passwall_key() {
    output="$1"
    urls="
        https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall/main/passwall.pub
        https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
        https://ghproxy.com/https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall/main/passwall.pub
        https://cdn.jsdelivr.net/gh/Openwrt-Passwall/openwrt-passwall@main/passwall.pub
    "

    for url in $urls; do
        log "尝试下载公钥: $(echo "$url" | sed 's|https://||')"
        rm -f "$output"
        if download_file "$url" "$output" && [ -s "$output" ]; then
            return 0
        fi
    done

    return 1
}

refresh_luci() {
    rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true
    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >/dev/null 2>&1 || warn "rpcd 重启失败"
    fi
}

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    die "已有另一个 PassWall2 任务正在运行"
fi

if command -v opkg >/dev/null 2>&1; then
    PKG_MGR="opkg"
elif command -v apk >/dev/null 2>&1; then
    die "当前环境包管理器为 apk（OpenWrt 25.12+），PassWall2 安装脚本尚未适配。\n  请使用 OpenWrt 25.11 或更早版本，或等待脚本更新。"
else
    die "未检测到 opkg 或 apk，当前系统暂不支持"
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
log "下载 PassWall 公钥..."
download_passwall_key passwall.pub || die "下载 PassWall 公钥失败"
opkg-key add /tmp/passwall.pub >/dev/null 2>&1 || true

for feed in passwall_luci passwall_packages passwall2; do
    echo "src/gz $feed $FEED_BASE/$feed" >> /etc/opkg/customfeeds.conf
done

log "刷新软件源"
opkg update

OLD_VER="$(opkg status luci-app-passwall2 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
log "当前已安装版本: ${OLD_VER:-not installed}"

log "按官方 IPK 方式安装 / 更新 PassWall2"
opkg install luci-app-passwall2 luci-i18n-passwall2-zh-cn

NEW_VER="$(opkg status luci-app-passwall2 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
log "安装后版本: ${NEW_VER:-unknown}"

refresh_luci
warn "默认不主动修改 /etc/config/passwall2；如界面初次显示异常，可手动刷新页面或重新登录 LuCI"
warn "如界面初次显示为英文，请刷新页面，中文语言包会自动生效"
log "PassWall2 处理完成"
