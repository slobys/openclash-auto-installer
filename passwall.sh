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
LOCKDIR="/tmp/passwall-install.lock"
TMP_ROOT="/tmp/passwall-install"
GH_API="https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall/releases/latest"
GH_REPO_PAGE="https://github.com/Openwrt-Passwall/openwrt-passwall"
SF_BASE="https://sourceforge.net/projects/openwrt-passwall-build/files"
TMPFILES=""

register_tmp() {
    TMPFILES="$TMPFILES $1"
}

cleanup() {
    for f in $TMPFILES; do
        rm -f "$f" 2>/dev/null || true
    done
    if [ "$LOCK_ACQUIRED" = "1" ]; then
        rm -rf "$TMP_ROOT"
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
        curl -fsSL --retry 3 --connect-timeout 15 "$url" -o "$output" && return 0
        warn "curl 下载失败（将尝试跳过证书验证重试）: $url"
        curl -kfsSL --retry 2 --connect-timeout 15 "$url" -o "$output" && return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO "$output" "$url" && return 0
        warn "wget 下载失败（将尝试跳过证书验证重试）: $url"
        wget --no-check-certificate -qO "$output" "$url" && return 0
    fi

    return 1
}

fetch_text() {
    url="$1"
    tmp="$(mktemp /tmp/passwall-page.XXXXXX)"
    register_tmp "$tmp"
    download_file "$url" "$tmp" || {
        rm -f "$tmp"
        return 1
    }
    cat "$tmp"
    rm -f "$tmp"
}

find_pkg_link() {
    page="$1"
    pkg="$2"
    ext="$3"
    link="$(printf '%s' "$page" | grep -o 'href="/projects/openwrt-passwall-build/files/[^"]*'"${pkg}"'[-_][^"]*\.'"${ext}"'[^"]*"' | sed 's|^href="||;s|"$||' | head -n1)"
    if [ -z "$link" ]; then
        warn "在 SourceForge 页面中未找到包: $pkg"
        return 1
    fi
    printf '%s\n' "$link"
}

download_pkg_from_dir() {
    pkg="$1"
    dir="$2"
    ext="$3"
    sf_dir_url="${SF_BASE}/${PACKAGE_DIR}/${dir}/"
    page="$(fetch_text "$sf_dir_url")" || {
        warn "无法获取目录页: $sf_dir_url"
        return 1
    }
    link="$(find_pkg_link "$page" "$pkg" "$ext")" || return 1

    case "$link" in
        */stats/timeline)
            link="${link%/stats/timeline}"
            ;;
    esac

    filename="$(basename "$link")"
    output="$TMP_ROOT/$filename"
    register_tmp "$output"
    download_url="https://sourceforge.net${link}/download"

    log "下载: $filename" >&2
    download_file "$download_url" "$output" || {
        warn "下载失败: $download_url"
        return 1
    }
    [ -s "$output" ] || {
        warn "下载文件为空: $output"
        return 1
    }
    printf '%s\n' "$output"
}

github_release_prefix() {
    case "$PKG_MGR:$SUPPORTED_RELEASE" in
        apk:*) printf '25.12+_' ;;
        opkg:24.10|opkg:23.05) printf '23.05-24.10_' ;;
        opkg:22.03) printf '22.03-_' ;;
        *) printf '' ;;
    esac
}

fetch_github_latest_tag_page() {
    page="$(fetch_text "${GH_REPO_PAGE}/releases/latest")" || return 1
    printf '%s\n' "$page" \
        | sed -n 's|.*href="/Openwrt-Passwall/openwrt-passwall/releases/tag/\([^"/?#]*\)".*|\1|p' \
        | head -n1
}

fetch_github_release_asset_urls_page() {
    tag="$1"
    [ -n "$tag" ] || return 1
    page="$(fetch_text "${GH_REPO_PAGE}/releases/expanded_assets/${tag}")" || return 1
    printf '%s\n' "$page" \
        | sed -n 's|.*href="\(/Openwrt-Passwall/openwrt-passwall/releases/download/[^"]*\)".*|https://github.com\1|p'
}

find_github_pkg_url() {
    pkg="$1"
    ext="$2"
    prefix="$(github_release_prefix)"
    [ -n "$prefix" ] || return 1
    {
        if [ -n "${GH_RELEASE_JSON:-}" ]; then
            printf '%s\n' "$GH_RELEASE_JSON" \
                | sed 's/"browser_download_url"/\
"browser_download_url"/g' \
                | sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/p'
        fi
        [ -z "${GH_RELEASE_ASSET_URLS:-}" ] || printf '%s\n' "$GH_RELEASE_ASSET_URLS"
    } \
        | sed 's/%2B/+/g' \
        | grep "/${prefix}[^/]*${pkg}[-_][0-9][^/]*\.${ext}$" \
        | head -n1
}

download_pkg_from_github_release() {
    pkg="$1"
    ext="$2"
    url="$(find_github_pkg_url "$pkg" "$ext")"
    [ -n "$url" ] || {
        warn "GitHub release assets 中未找到包: $pkg"
        return 1
    }

    filename="$(basename "$url" | sed 's/%2B/+/g')"
    output="$TMP_ROOT/$filename"
    register_tmp "$output"

    log "下载: $filename" >&2
    download_file "$url" "$output" || download_file "https://gh-proxy.com/$url" "$output" || {
            warn "下载失败: $url"
            return 1
        }
    [ -s "$output" ] || {
        warn "下载文件为空: $output"
        return 1
    }
    printf '%s\n' "$output"
}

download_passwall_pkg() {
    pkg="$1"
    dir="$2"
    ext="$3"

    if [ -n "${GH_RELEASE_JSON:-}${GH_RELEASE_ASSET_URLS:-}" ]; then
        download_pkg_from_github_release "$pkg" "$ext" && return 0
        warn "GitHub release assets 下载失败，回退 SourceForge 目录。"
    fi

    download_pkg_from_dir "$pkg" "$dir" "$ext"
}

install_signed_apk() {
    need_cmd sha256sum
    key_tmp="$(mktemp /tmp/passwall-key.XXXXXX)"
    register_tmp "$key_tmp"
    download_file "$SF_BASE/apk.pub/download" "$key_tmp" || die "下载 PassWall APK 签名公钥失败"
    key_digest="$(sha256sum "$key_tmp" | awk '{print $1}')"
    [ "$key_digest" = "52802b143489214e13b78f96599a147a638205cc22d9dd6d71229504e38ddc00" ] ||
        die "PassWall APK 公钥摘要不匹配；请先核实上游是否更换签名密钥"
    mkdir -p /etc/apk/keys
    cp "$key_tmp" /etc/apk/keys/passwall.pub

    feed_base="$SF_BASE/$PACKAGE_DIR"
    log "使用 PassWall 官方签名 APK 源（不跳过签名验证）"
    apk add --upgrade --cache-predownload --cache-max-age 0 \
        -X "$feed_base/passwall_packages/packages.adb" \
        -X "$feed_base/passwall_luci/packages.adb" \
        luci-app-passwall luci-i18n-passwall-zh-cn ||
        die "签名源安装 passwall 失败；请检查网络、当前架构的软件包及系统软件源"
    apk info -e luci-app-passwall >/dev/null 2>&1 || die "passwall 主包未登记到 APK 数据库"
    apk info -e luci-i18n-passwall-zh-cn >/dev/null 2>&1 || die "passwall 中文包未登记到 APK 数据库"
    NEW_VER="$(get_installed_version luci-app-passwall)"
    [ -n "$NEW_VER" ] || die "无法读取 passwall 安装后版本"
    log "安装后版本: $NEW_VER"
    if [ -n "$GH_LATEST" ] && [ "$NEW_VER" != "$(printf '%s' "$GH_LATEST" | sed 's/-\([0-9][0-9]*\)$/-r\1/')" ]; then
        warn "签名源版本 $NEW_VER 与 GitHub Release $GH_LATEST 不同；保留签名源版本，不强制安装未验证签名的包"
    fi
    refresh_luci
    warn "保留现有 /etc/config/passwall；请刷新 LuCI 页面"
    log "passwall 处理完成"
}

is_package_installed() {
    pkg="$1"
    case "$PKG_MGR" in
        opkg) opkg list-installed "$pkg" 2>/dev/null | grep -q "^${pkg} -" ;;
        apk) apk info -e "$pkg" >/dev/null 2>&1 ;;
    esac
}

get_installed_version() {
    pkg="$1"
    case "$PKG_MGR" in
        opkg)
            opkg status "$pkg" 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true
            ;;
        apk)
            VER="$(apk list --installed --manifest "$pkg" 2>/dev/null | awk -v name="$pkg" '$1 == name {print $2; exit}' || true)"
            [ -n "$VER" ] || VER="$(apk info -a "$pkg" 2>/dev/null | sed -n 's/^[Vv]ersion:[[:space:]]*//p' | head -n1 || true)"
            printf '%s' "$VER"
            ;;
    esac
}

maybe_update_pkg_index() {
    case "$PKG_MGR" in
        opkg) opkg update || warn "opkg update 未完全成功，将继续使用已缓存的软件源索引" ;;
        apk) apk update || warn "apk update 未完全成功，将继续使用已缓存的软件源索引" ;;
    esac
}

install_passwall_dependency() {
    pkg="$1"
    is_package_installed "$pkg" && return 0

    log "安装 PassWall 依赖: $pkg"
    case "$PKG_MGR" in
        opkg) opkg install "$pkg" >/dev/null 2>&1 && return 0 ;;
        apk) apk add "$pkg" >/dev/null 2>&1 && return 0 ;;
    esac

    dep_pkg="$(download_pkg_from_dir "$pkg" passwall_packages "$PKG_EXT")" ||
        die "无法从软件源或 PassWall 构建目录获取依赖: $pkg"
    case "$PKG_MGR" in
        opkg) opkg install "$dep_pkg" || die "安装 PassWall 依赖失败: $pkg" ;;
        apk) apk add --allow-untrusted "$dep_pkg" || die "安装 PassWall 依赖失败: $pkg" ;;
    esac
}

install_passwall_dependencies() {
    for pkg in chinadns-ng dns2socks microsocks tcping; do
        install_passwall_dependency "$pkg"
    done
}

ensure_dnsmasq_full() {
    is_package_installed dnsmasq-full && return 0

    log "安装 PassWall 必需的 dnsmasq-full"
    case "$PKG_MGR" in
        opkg)
            if is_package_installed dnsmasq; then
                opkg install --force-overwrite dnsmasq-full ||
                    die "安装 dnsmasq-full 失败；原 dnsmasq 尚未移除"
                opkg remove dnsmasq ||
                    die "dnsmasq-full 已安装，但无法移除冲突的 dnsmasq 包"
            else
                opkg install dnsmasq-full || die "安装 dnsmasq-full 失败"
            fi
            ;;
        apk)
            apk add dnsmasq-full || die "安装 dnsmasq-full 失败"
            ;;
    esac
}

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    die "已有另一个 PassWall 任务正在运行"
fi
LOCK_ACQUIRED="1"
mkdir -p "$TMP_ROOT"

PKG_MGR="$(detect_pkg_mgr)"

need_cmd "$PKG_MGR"
need_cmd sed
need_cmd grep
need_cmd basename
need_cmd mktemp
need_cmd awk

[ -f /etc/openwrt_release ] || die "未检测到 /etc/openwrt_release"
# shellcheck disable=SC1091
. /etc/openwrt_release

ARCH="${DISTRIB_ARCH:-}"
REL_RAW="${DISTRIB_RELEASE:-}"
TARGET_NAME="${DISTRIB_TARGET:-}"
[ -n "$ARCH" ] || die "无法识别系统架构"
[ -n "$REL_RAW" ] || die "无法识别系统版本"

normalize_release_for_passwall() {
    rel="$1"
    pkg_mgr="$2"
    case "$rel:$pkg_mgr" in
        25.*:apk) printf '25.12' ;;
        25.*:opkg|24.[0-9]*:*) printf '24.10' ;;
        23.05:opkg|23.05.[0-9]*:opkg) printf '23.05' ;;
        22.03:opkg|22.03.[0-9]*:opkg) printf '22.03' ;;
        *SNAPSHOT*) printf 'snapshots' ;;
        *) printf '' ;;
    esac
}

SUPPORTED_RELEASE="$(normalize_release_for_passwall "$REL_RAW" "$PKG_MGR")"
[ -n "$SUPPORTED_RELEASE" ] || die "当前系统版本 ${REL_RAW} / 包管理器 ${PKG_MGR} 暂未适配 PassWall 安装脚本。建议使用 OpenWrt 25.12+ apk，或 OpenWrt/iStoreOS/ImmortalWrt 22.03、23.05、24.10 opkg 系。"

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
log "Package manager: $PKG_MGR"
[ -n "$TARGET_NAME" ] && log "Target: $TARGET_NAME"
log "Package dir: $PACKAGE_DIR"
if [ "$SUPPORTED_RELEASE" != "$REL_RAW" ]; then
    warn "当前系统版本 ${REL_RAW} 将按兼容目录 ${SUPPORTED_RELEASE} 匹配 PassWall 软件源。"
fi
if [ "$PKG_MGR" = "apk" ]; then
    warn "检测到 OpenWrt 25.12+ apk 环境，将尝试安装上游 .apk 包；若上游尚未发布当前架构构建，会明确失败。"
fi

GH_RELEASE_JSON="$(fetch_text "$GH_API" 2>/dev/null || true)"
GH_LATEST="$(printf '%s' "$GH_RELEASE_JSON" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)"
if [ -z "$GH_LATEST" ]; then
    GH_LATEST="$(fetch_github_latest_tag_page 2>/dev/null || true)"
fi
[ -n "$GH_LATEST" ] && log "GitHub latest release: $GH_LATEST"
GH_RELEASE_ASSET_URLS=""
if [ -z "$GH_RELEASE_JSON" ] && [ -n "$GH_LATEST" ]; then
    GH_RELEASE_ASSET_URLS="$(fetch_github_release_asset_urls_page "$GH_LATEST" 2>/dev/null || true)"
    [ -n "$GH_RELEASE_ASSET_URLS" ] && log "GitHub release assets: 已通过网页兜底获取"
fi

case "$PKG_MGR" in
    opkg)
        PKG_EXT="ipk"
        ;;
    apk)
        PKG_EXT="apk"
        ;;
    *)
        die "未知包管理器: $PKG_MGR"
        ;;
esac
OLD_VER="$(get_installed_version luci-app-passwall)"
log "当前已安装版本: ${OLD_VER:-not installed}"
log "按接近手动 ${PKG_EXT} 的方式安装 / 更新 PassWall"
if [ "$PKG_MGR" = "apk" ]; then
    install_signed_apk
    exit 0
fi
maybe_update_pkg_index

install_lyaml_fallback() {
    case "$SUPPORTED_RELEASE" in
        24.10)
            dep_path="releases/${REL_RAW}/packages/${ARCH}/packages"
            ;;
        *)
            return 1
            ;;
    esac

    for mirror in \
        "https://downloads.openwrt.org" \
        "https://mirrors.tuna.tsinghua.edu.cn/openwrt" \
        "https://mirrors.ustc.edu.cn/openwrt" \
        "https://mirrors.aliyun.com/openwrt" \
        "https://mirrors.cernet.edu.cn/openwrt"
    do
        dep_base="${mirror}/${dep_path}"
        log "软件源安装 lyaml 失败，尝试从 ${dep_base} 直接下载依赖 IPK"
        dir_page="$(fetch_text "${dep_base}/")" || {
            warn "无法获取依赖目录: ${dep_base}/"
            continue
        }

        libyaml_name="$(printf '%s' "$dir_page" | grep -o "libyaml_[^\"'<>]*_${ARCH}\.ipk" | head -n1)"
        lyaml_name="$(printf '%s' "$dir_page" | grep -o "lyaml_[^\"'<>]*_${ARCH}\.ipk" | head -n1)"
        [ -n "$libyaml_name" ] || {
            warn "未找到 libyaml IPK（架构: $ARCH）"
            continue
        }
        [ -n "$lyaml_name" ] || {
            warn "未找到 lyaml IPK（架构: $ARCH）"
            continue
        }

        libyaml_ipk="$TMP_ROOT/$libyaml_name"
        lyaml_ipk="$TMP_ROOT/$lyaml_name"
        register_tmp "$libyaml_ipk"
        register_tmp "$lyaml_ipk"

        log "下载依赖: $libyaml_name"
        download_file "${dep_base}/${libyaml_name}" "$libyaml_ipk" || continue
        log "下载依赖: $lyaml_name"
        download_file "${dep_base}/${lyaml_name}" "$lyaml_ipk" || continue

        opkg install "$libyaml_ipk" "$lyaml_ipk" && return 0
    done

    return 1
}

if [ "$PKG_MGR" = "opkg" ] && ! opkg list-installed lyaml 2>/dev/null | grep -q '^lyaml -'; then
    log "安装依赖: lyaml"
    opkg install lyaml || install_lyaml_fallback || die "安装依赖 lyaml 失败。请检查系统软件源是否启用 packages 源，或手动执行: opkg update && opkg install lyaml"
fi

install_passwall_dependencies
ensure_dnsmasq_full

MAIN_PKG="$(download_passwall_pkg luci-app-passwall passwall_luci "$PKG_EXT")" || die "下载 luci-app-passwall ${PKG_EXT} 失败，请检查当前系统版本/架构是否存在对应构建，或稍后重试。"
LANG_PKG="$(download_passwall_pkg luci-i18n-passwall-zh-cn passwall_luci "$PKG_EXT")" || die "下载 luci-i18n-passwall-zh-cn ${PKG_EXT} 失败，请稍后重试。"

case "$PKG_MGR" in
    opkg)
        INSTALL_OK=1
        if opkg install "$MAIN_PKG" "$LANG_PKG"; then
            INSTALL_OK=0
        fi
        ;;
    apk)
        INSTALL_OK=1
        if apk add --allow-untrusted "$MAIN_PKG" "$LANG_PKG"; then
            INSTALL_OK=0
        fi
        ;;
esac

if [ "$INSTALL_OK" -ne 0 ]; then
    cat >&2 <<EOF
[ERROR] PassWall 安装失败。
可能原因：
1. 当前固件版本与 PassWall 预编译包不匹配
2. 当前架构缺少对应依赖包，或软件源中没有兼容构建
3. 第三方固件重写了软件源，导致依赖解析异常

建议排查：
- OpenWrt 25.12+ / apk 环境请确认上游已发布对应 .apk 构建
- opkg 环境确认系统版本优先使用 22.03 / 23.05 / 24.10 系
- 执行 ${PKG_MGR} update 后重试
- 检查系统软件源配置是否存在异常或重复源
- 如为 iStoreOS 24.10 / 非标准固件，可优先使用 OpenClash，PassWall 兼容性取决于上游构建
EOF
    exit 1
fi

NEW_VER="$(get_installed_version luci-app-passwall)"
log "安装后版本: ${NEW_VER:-unknown}"

refresh_luci
warn "默认不主动修改 /etc/config/passwall；如界面初次显示异常，可手动刷新页面或重新登录 LuCI"
warn "如界面初次显示为英文，请刷新页面，中文语言包会自动生效"
log "PassWall 处理完成"
