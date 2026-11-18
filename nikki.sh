#!/bin/sh
set -eu

detect_pkg_mgr() {
    # Some APK firmware still ships the opkg executable without usable feeds.
    if command -v apk >/dev/null 2>&1 && [ -s /lib/apk/db/installed ]; then
        printf 'apk'
    elif command -v opkg >/dev/null 2>&1; then
        printf 'opkg'
    elif command -v apk >/dev/null 2>&1; then
        printf 'apk'
    else
        printf '%s\n' "[ERROR] 未检测到 opkg 或 apk" >&2
        return 1
    fi
}

LOCK_ACQUIRED="0"
LOCKDIR="/tmp/nikki-install.lock"
FEED_SCRIPT_URL="https://raw.githubusercontent.com/nikkinikki-org/OpenWrt-nikki/main/feed.sh"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/nikkinikki-org/OpenWrt-nikki/main/install.sh"
NIKKI_REPO_URL="https://nikkinikki.pages.dev"
TMP_SCRIPT=""

cleanup() {
    [ -z "$TMP_SCRIPT" ] || rm -f "$TMP_SCRIPT"
    if [ "$LOCK_ACQUIRED" = "1" ]; then
        rmdir "$LOCKDIR" 2>/dev/null || true
    fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

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

run_official_script() {
    script_url="$1"
    TMP_SCRIPT="$(mktemp /tmp/nikki-script.XXXXXX)"
    wget -qO "$TMP_SCRIPT" "$script_url" || die "下载 Nikki 官方脚本失败: $script_url"
    [ -s "$TMP_SCRIPT" ] || die "Nikki 官方脚本为空: $script_url"
    sh "$TMP_SCRIPT" || die "执行 Nikki 官方脚本失败: $script_url"
    rm -f "$TMP_SCRIPT"
    TMP_SCRIPT=""
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

detect_nikki_branch() {
    case "${REL_RAW:-}" in
        *24.10*) printf 'openwrt-24.10' ;;
        *25.12*) printf 'openwrt-25.12' ;;
        SNAPSHOT) printf 'SNAPSHOT' ;;
        *) printf '' ;;
    esac
}

add_nikki_apk_feed() {
    branch="$(detect_nikki_branch)"
    [ -n "$branch" ] || die "当前系统版本 ${REL_RAW:-unknown} 暂未被 Nikki 官方 feed 支持"

    arch="${DISTRIB_ARCH:-}"
    [ -n "$arch" ] || die "无法识别系统架构"

    FEED_URL="$NIKKI_REPO_URL/$branch/$arch/nikki"
    feed_list="/etc/apk/repositories.d/customfeeds.list"

    log "导入 Nikki apk feed: $FEED_URL"
    mkdir -p /etc/apk/keys /etc/apk/repositories.d
    wget -qO /etc/apk/keys/nikki.pem "$NIKKI_REPO_URL/public-key.pem" || die "下载 Nikki apk 公钥失败"

    if [ -f "$feed_list" ] && grep -q nikki "$feed_list"; then
        sed -i '/nikki/d' "$feed_list"
    fi
    printf '%s\n' "$FEED_URL/packages.adb" >> "$feed_list"
}

get_installed_nikki_version() {
    case "$PKG_MGR" in
        opkg)
            opkg status luci-app-nikki 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true
            ;;
        apk)
            VER="$(apk list --installed --manifest luci-app-nikki 2>/dev/null | awk '$1 == "luci-app-nikki" {print $2; exit}' || true)"
            [ -n "$VER" ] || VER="$(apk info -a luci-app-nikki 2>/dev/null | sed -n 's/^[Vv]ersion:[[:space:]]*//p' | head -n1 || true)"
            printf '%s' "$VER"
            ;;
    esac
}

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    die "已有另一个 Nikki 任务正在运行"
fi
LOCK_ACQUIRED="1"

[ -f /etc/openwrt_release ] || die "未检测到 /etc/openwrt_release"
# shellcheck disable=SC1091
. /etc/openwrt_release

REL_RAW="${DISTRIB_RELEASE:-}"
log "System release: ${REL_RAW:-unknown}"

need_cmd wget
need_cmd awk

PKG_MGR="$(detect_pkg_mgr)"

log "检测到包管理器: $PKG_MGR"
FIREWALL_STACK="$(detect_firewall_stack)"
log "检测到防火墙栈: $FIREWALL_STACK"
if [ "$FIREWALL_STACK" = "iptables" ]; then
    cat >&2 <<EOF
[ERROR] Nikki 仅支持 firewall4（nftables）环境。
当前系统防火墙栈为 iptables，因此无法直接安装 Nikki。

建议处理方式：
- 切换到使用 firewall4 的 OpenWrt / ImmortalWrt / iStoreOS 固件
- 或改用 OpenClash / PassWall / PassWall2
EOF
    exit 1
fi
NIKKI_BRANCH="$(detect_nikki_branch)"
[ -n "$NIKKI_BRANCH" ] || die "Nikki 官方源不支持 ${REL_RAW:-unknown}；支持 24.10、25.12 和 SNAPSHOT，不能仅修改版本号强行安装"
log "匹配 Nikki 官方 feed: $NIKKI_BRANCH / ${DISTRIB_ARCH:-unknown}"

case "$PKG_MGR" in
    opkg)
        OLD_VER="$(get_installed_nikki_version)"
        log "当前已安装版本: ${OLD_VER:-not installed}"
        log "按官方方式导入 Nikki feed"
        run_official_script "$FEED_SCRIPT_URL"
        log "按官方方式安装 / 更新 Nikki"
        run_official_script "$INSTALL_SCRIPT_URL"
        opkg install luci-i18n-nikki-zh-cn || warn "安装 Nikki 中文语言包失败"
        NEW_VER="$(get_installed_nikki_version)"
        ;;
    apk)
        OLD_VER="$(get_installed_nikki_version)"
        log "当前已安装版本: ${OLD_VER:-not installed}"
        add_nikki_apk_feed
        log "刷新软件源"
        apk update || die "apk update 失败，请检查 Nikki feed 或网络连接"
        log "按 Nikki 官方 apk feed 安装 / 更新 Nikki"
        apk add -X "$FEED_URL/packages.adb" mihomo-meta nikki luci-app-nikki || die "安装 Nikki apk 包失败，请检查当前架构是否存在 Nikki 官方构建"
        apk add -X "$FEED_URL/packages.adb" luci-i18n-nikki-zh-cn || warn "安装 Nikki 中文语言包失败"
        NEW_VER="$(get_installed_nikki_version)"
        ;;
esac

[ -n "$NEW_VER" ] || die "安装后未查到 luci-app-nikki 版本，不能确认安装成功"
log "安装后版本: $NEW_VER"
refresh_luci
warn "默认不主动改写 Nikki 配置；如界面初次显示异常，可手动刷新页面或重新登录 LuCI"
warn "如界面初次显示为英文，请刷新页面，中文语言包会自动生效"
log "Nikki 处理完成"
