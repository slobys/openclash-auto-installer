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

refresh_luci() {
    rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true
    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >/dev/null 2>&1 || warn "rpcd 重启失败"
    fi
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

fetch_text() {
    url="$1"
    tmp="/tmp/passwall2-page.$$"
    rm -f "$tmp"
    download_file "$url" "$tmp" || return 1
    cat "$tmp"
    rm -f "$tmp"
}

find_pkg_link() {
    page="$1"
    pkg="$2"
    printf '%s' "$page" | grep -o 'href="/projects/openwrt-passwall-build/files/[^"]*'"${pkg}"'_[^"]*\.ipk[^"]*"' | sed 's|^href="||;s|"$||' | head -n1
}

download_pkg_from_dir() {
    pkg="$1"
    dir="$2"
    sf_dir_url="https://sourceforge.net/projects/openwrt-passwall-build/files/${PACKAGE_DIR}/${dir}/"
    page="$(fetch_text "$sf_dir_url")" || return 1
    link="$(find_pkg_link "$page" "$pkg")"
    [ -n "$link" ] || return 1

    case "$link" in
        */stats/timeline)
            link="${link%/stats/timeline}"
            ;;
    esac

    filename="$(basename "$link")"
    output="/tmp/$filename"
    download_url="https://sourceforge.net${link}/download"

    printf '%s\n' "==> 下载: $filename" >&2
    download_file "$download_url" "$output" || return 1
    [ -s "$output" ] || return 1
    printf '%s\n' "$output"
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
need_cmd sed
need_cmd grep
need_cmd basename

[ -f /etc/openwrt_release ] || die "未检测到 /etc/openwrt_release"
# shellcheck disable=SC1091
. /etc/openwrt_release

ARCH="${DISTRIB_ARCH:-}"
REL_RAW="${DISTRIB_RELEASE:-}"
TARGET_NAME="${DISTRIB_TARGET:-}"
[ -n "$ARCH" ] || die "无法识别系统架构"
[ -n "$REL_RAW" ] || die "无法识别系统版本"

normalize_release_for_passwall2() {
    case "$1" in
        25.*|24.*) printf '24.10' ;;
        23.05*|23.0*) printf '23.05' ;;
        22.03*|22.0*) printf '22.03' ;;
        *SNAPSHOT*) printf 'snapshots' ;;
        *) printf '' ;;
    esac
}

SUPPORTED_RELEASE="$(normalize_release_for_passwall2 "$REL_RAW")"
[ -n "$SUPPORTED_RELEASE" ] || die "当前系统版本 ${REL_RAW} 暂未适配 PassWall2 安装脚本。建议使用 OpenWrt/iStoreOS/ImmortalWrt 22.03、23.05、24.10 系，或反馈 issue 补充适配。"

case "$SUPPORTED_RELEASE" in
    snapshots)
        PACKAGE_DIR="snapshots/packages/$ARCH"
        ;;
    *)
        PACKAGE_DIR="releases/packages-$SUPPORTED_RELEASE/$ARCH"
        ;;
esac

log "System release: $REL_RAW"
log "Arch: $ARCH"
[ -n "$TARGET_NAME" ] && log "Target: $TARGET_NAME"
log "Package dir: $PACKAGE_DIR"
if [ "$SUPPORTED_RELEASE" != "$REL_RAW" ]; then
    warn "当前系统版本 ${REL_RAW} 将按兼容目录 ${SUPPORTED_RELEASE} 匹配 PassWall2 软件源。"
fi

GH_LATEST="$(fetch_text "$GH_API" 2>/dev/null | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)"
[ -n "$GH_LATEST" ] && log "GitHub latest release: $GH_LATEST"

OLD_VER="$(opkg status luci-app-passwall2 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
log "当前已安装版本: ${OLD_VER:-not installed}"
log "按接近手动 IPK 的方式安装 / 更新 PassWall2"

MAIN_IPK="$(download_pkg_from_dir luci-app-passwall2 passwall2)" || die "下载 luci-app-passwall2 失败，请检查当前系统版本/架构是否存在对应构建，或稍后重试。"
LANG_IPK="$(download_pkg_from_dir luci-i18n-passwall2-zh-cn passwall2)" || die "下载 luci-i18n-passwall2-zh-cn 失败，请稍后重试。"

if ! opkg install "$MAIN_IPK" "$LANG_IPK"; then
    cat >&2 <<EOF
[ERROR] PassWall2 安装失败。
可能原因：
1. 当前固件版本与 PassWall2 预编译包不匹配
2. 当前架构缺少对应依赖包，或软件源中没有兼容构建
3. 第三方固件重写了软件源，导致依赖解析异常

建议排查：
- 确认系统版本优先使用 22.03 / 23.05 / 24.10 系
- 执行 opkg update 后重试
- 检查 /etc/opkg/customfeeds.conf 是否存在异常或重复源
- 如为非标准固件（如 QWRT / GDQ 等），兼容性取决于上游是否提供对应构建
EOF
    exit 1
fi

NEW_VER="$(opkg status luci-app-passwall2 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
log "安装后版本: ${NEW_VER:-unknown}"

refresh_luci
warn "默认不主动修改 /etc/config/passwall2；如界面初次显示异常，可手动刷新页面或重新登录 LuCI"
warn "如界面初次显示为英文，请刷新页面，中文语言包会自动生效"
log "PassWall2 处理完成"
