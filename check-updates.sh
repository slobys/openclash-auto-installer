#!/bin/sh
set -eu

TMP_ROOT="/tmp/plugin-update-check"
OPENCLASH_API="https://api.github.com/repos/vernesong/OpenClash/releases/latest"
PASSWALL_API="https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall/releases/latest"
PASSWALL2_API="https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall2/releases/latest"
NIKKI_REPO_API="https://api.github.com/repos/nikkinikki-org/OpenWrt-nikki/releases/latest"
SMARTDNS_API="https://api.github.com/repos/pymumu/smartdns/releases/latest"
MOSDNS_API="https://api.github.com/repos/sbwml/luci-app-mosdns/releases/latest"
DAED_RELEASES_API="https://api.github.com/repos/daeuniverse/daed/releases?per_page=20"
TARGET="all"

cleanup() {
    rm -rf "$TMP_ROOT"
}

trap cleanup EXIT INT TERM
mkdir -p "$TMP_ROOT"

log() {
    printf '%s\n' "==> $*"
}

warn() {
    printf '%s\n' "[WARN] $*" >&2
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        printf '%s\n' "[ERROR] 缺少命令: $1" >&2
        exit 1
    }
}

usage() {
    cat <<'EOF_USAGE'
用法:
  sh check-updates.sh
  sh check-updates.sh --all
  sh check-updates.sh --openclash
  sh check-updates.sh --passwall
  sh check-updates.sh --passwall2
  sh check-updates.sh --nikki
  sh check-updates.sh --smartdns
  sh check-updates.sh --mosdns
  sh check-updates.sh --daed

说明:
  默认检查全部插件
EOF_USAGE
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --all)
                TARGET="all"
                ;;
            --openclash)
                TARGET="openclash"
                ;;
            --passwall)
                TARGET="passwall"
                ;;
            --passwall2)
                TARGET="passwall2"
                ;;
            --nikki)
                TARGET="nikki"
                ;;
            --smartdns)
                TARGET="smartdns"
                ;;
            --mosdns)
                TARGET="mosdns"
                ;;
            --daed)
                TARGET="daed"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                printf '%s\n' "[ERROR] 未知参数: $1" >&2
                exit 1
                ;;
        esac
        shift
    done
}

normalize_version() {
    VER="${1:-}"
    VER="${VER#v}"
    VER="${VER#Release}"
    VER="${VER%%-*}"
    printf '%s' "$VER"
}

fetch_latest_tag_jsonfilter() {
    NAME="$1"
    URL="$2"
    OUT="$TMP_ROOT/$NAME.json"
    TAG=""
    if fetch_url "$URL" "$OUT"; then
        TAG="$(sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' "$OUT" | head -n1)"
    fi
    [ -n "$TAG" ] || TAG="$(fetch_latest_tag_page "$URL" "$TMP_ROOT/$NAME.html" || true)"
    printf '%s\n' "$TAG"
}

fetch_latest_tag_wget_sed() {
    URL="$1"
    OUT="$TMP_ROOT/latest-tag.json"
    TAG=""
    if fetch_url "$URL" "$OUT"; then
        TAG="$(sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' "$OUT" | head -n1)"
    fi
    [ -n "$TAG" ] || TAG="$(fetch_latest_tag_page "$URL" "$TMP_ROOT/latest-tag.html" || true)"
    printf '%s\n' "$TAG"
}

fetch_latest_tag_page() {
    API_URL="$1"
    OUT="$2"

    PAGE_URL="$(printf '%s' "$API_URL" | sed 's|^https://api.github.com/repos/\([^/]*\)/\([^/]*\)/releases/latest$|https://github.com/\1/\2/releases/latest|')"
    [ "$PAGE_URL" != "$API_URL" ] || return 1

    fetch_url "$PAGE_URL" "$OUT" || return 1
    sed -n 's|.*href="/[^"]*/releases/tag/\([^"/?#]*\)".*|\1|p' "$OUT" | head -n1
}

fetch_url() {
    URL="$1"
    OUT="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --connect-timeout 15 "$URL" -o "$OUT" 2>/dev/null && return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO "$OUT" "$URL" 2>/dev/null && return 0
    fi

    return 1
}

print_result() {
    NAME="$1"
    INSTALLED="$2"
    LATEST="$3"

    printf '%s\n' ""
    printf '%s\n' "[$NAME]"
    printf '  当前版本: %s\n' "${INSTALLED:-not installed}"
    printf '  最新版本: %s\n' "${LATEST:-unknown}"

    if [ -z "${LATEST:-}" ]; then
        printf '%s\n' "  状态: 无法获取最新版本"
        return 0
    fi

    if [ -z "${INSTALLED:-}" ]; then
        printf '%s\n' "  状态: 未安装"
        return 0
    fi

    if [ "$INSTALLED" = "installed" ]; then
        printf '%s\n' "  状态: 已安装，无法比较版本"
        return 0
    fi

    INSTALLED_NORM="$(normalize_version "$INSTALLED")"
    LATEST_NORM="$(normalize_version "$LATEST")"

    if [ "$INSTALLED_NORM" = "$LATEST_NORM" ]; then
        printf '%s\n' "  状态: 已是最新"
    else
        printf '%s\n' "  状态: 有新版本可更新"
    fi
}

print_result_no_compare() {
    NAME="$1"
    INSTALLED="$2"
    LATEST="$3"
    NOTE="$4"

    printf '%s\n' ""
    printf '%s\n' "[$NAME]"
    printf '  当前版本: %s\n' "${INSTALLED:-not installed}"
    printf '  最新版本: %s\n' "${LATEST:-unknown}"

    if [ -z "${INSTALLED:-}" ]; then
        printf '%s\n' "  状态: 未安装"
    else
        printf '%s\n' "  状态: 已安装，版本仅供参考"
    fi
    [ -z "${NOTE:-}" ] || printf '  说明: %s\n' "$NOTE"
}

get_installed_opkg_version() {
    PKG="$1"
    opkg status "$PKG" 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true
}

get_installed_apk_version() {
    for PKG in "$@"; do
        apk info -e "$PKG" >/dev/null 2>&1 || continue

        VER="$(apk list --installed --manifest "$PKG" 2>/dev/null | awk -v pkg="$PKG" '$1 == pkg {print $2; exit}' || true)"
        [ -n "$VER" ] || VER="$(apk list --installed "$PKG" 2>/dev/null | sed -n 's/^'"$PKG"'-\([^[:space:]]*\).*/\1/p' | head -n1 || true)"
        [ -n "$VER" ] || VER="$(apk info -v "$PKG" 2>/dev/null | sed -n 's/^'"$PKG"'-\([^[:space:]]*\).*/\1/p' | head -n1 || true)"
        [ -n "$VER" ] || VER="$(apk info -a "$PKG" 2>/dev/null | sed -n 's/^[Vv]ersion:[[:space:]]*//p' | head -n1 || true)"
        printf '%s' "${VER:-installed}"
        return 0
    done

    printf ''
}

get_mosdns_runtime_version() {
    command -v mosdns >/dev/null 2>&1 || return 0
    mosdns version 2>/dev/null | sed -n 's/.*\(v[0-9][0-9A-Za-z._-]*\).*/\1/p' | head -n1 || true
}

check_openclash() {
    if [ "$PKG_MGR" = "opkg" ]; then
        INSTALLED="$(get_installed_opkg_version luci-app-openclash)"
    else
        INSTALLED="$(get_installed_apk_version luci-app-openclash)"
    fi

    LATEST="$(fetch_latest_tag_jsonfilter openclash "$OPENCLASH_API" || true)"
    print_result "OpenClash" "$INSTALLED" "$LATEST"
}

check_passwall() {
    if [ "$PKG_MGR" = "opkg" ]; then
        INSTALLED="$(get_installed_opkg_version luci-app-passwall)"
    else
        INSTALLED="$(get_installed_apk_version luci-app-passwall)"
    fi

    LATEST="$(fetch_latest_tag_wget_sed "$PASSWALL_API" || true)"
    print_result "PassWall" "$INSTALLED" "$LATEST"
}

check_passwall2() {
    if [ "$PKG_MGR" = "opkg" ]; then
        INSTALLED="$(get_installed_opkg_version luci-app-passwall2)"
    else
        INSTALLED="$(get_installed_apk_version luci-app-passwall2)"
    fi

    LATEST="$(fetch_latest_tag_wget_sed "$PASSWALL2_API" || true)"
    print_result "PassWall2" "$INSTALLED" "$LATEST"
}

check_smartdns() {
    if [ "$PKG_MGR" = "opkg" ]; then
        INSTALLED="$(get_installed_opkg_version smartdns)"
    else
        INSTALLED="$(get_installed_apk_version smartdns luci-app-smartdns)"
    fi

    LATEST="$(fetch_latest_tag_jsonfilter smartdns "$SMARTDNS_API" || true)"
    print_result_no_compare "SmartDNS" "$INSTALLED" "$LATEST" "SmartDNS 软件包版本与 GitHub Release 标签不是同一套版本号，不直接判断是否可更新"
}

check_mosdns() {
    INSTALLED="$(get_mosdns_runtime_version)"
    if [ -z "${INSTALLED:-}" ] && [ "$PKG_MGR" = "opkg" ]; then
        INSTALLED="$(get_installed_opkg_version mosdns)"
    else
        [ -n "${INSTALLED:-}" ] || INSTALLED="$(get_installed_apk_version mosdns luci-app-mosdns)"
    fi

    LATEST="$(fetch_latest_tag_jsonfilter mosdns "$MOSDNS_API" || true)"
    print_result "MosDNS" "$INSTALLED" "$LATEST"
}

check_nikki() {
    if [ "$PKG_MGR" = "opkg" ]; then
        INSTALLED="$(get_installed_opkg_version luci-app-nikki)"
    else
        INSTALLED="$(get_installed_apk_version luci-app-nikki nikki)"
    fi

    LATEST="$(fetch_latest_tag_jsonfilter nikki "$NIKKI_REPO_API" || true)"
    print_result "Nikki" "$INSTALLED" "$LATEST"
    if [ -z "${LATEST:-}" ]; then
        printf '%s\n' "  说明: Nikki 官方安装方式更偏 feed/脚本，GitHub Release 可能不是唯一更新来源"
    fi
}

check_daed() {
    INSTALLED=""
    if command -v daed >/dev/null 2>&1; then
        INSTALLED="$(daed --version 2>/dev/null | awk '{print $NF}' | head -n1 || true)"
        [ -n "$INSTALLED" ] || INSTALLED="installed"
    fi

    OUT="$TMP_ROOT/daed-releases.json"
    LATEST=""
    if fetch_url "$DAED_RELEASES_API" "$OUT"; then
        LATEST="$(sed 's/"tag_name"/\
"tag_name"/g' "$OUT" |
            sed -n 's/^"tag_name"[[:space:]]*:[[:space:]]*"\(v[0-9][^"]*\)".*/\1/p' |
            head -n1 || true)"
    fi
    print_result "daed" "$INSTALLED" "$LATEST"
}

main() {
    parse_args "$@"

    need_cmd sed
    need_cmd head
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        printf '%s\n' "[ERROR] 缺少 curl 或 wget，无法联网检查更新" >&2
        exit 1
    fi

    if command -v opkg >/dev/null 2>&1; then
        PKG_MGR="opkg"
    elif command -v apk >/dev/null 2>&1; then
        PKG_MGR="apk"
    else
        printf '%s\n' "[ERROR] 未检测到 opkg 或 apk" >&2
        exit 1
    fi

    log "开始检查插件更新状态"
    log "检测到包管理器: $PKG_MGR"

    case "$TARGET" in
        all)
            check_openclash
            check_passwall
            check_passwall2
            check_nikki
            check_smartdns
            check_mosdns
            check_daed
            ;;
        openclash)
            check_openclash
            ;;
        passwall)
            check_passwall
            ;;
        passwall2)
            check_passwall2
            ;;
        nikki)
            check_nikki
            ;;
        smartdns)
            check_smartdns
            ;;
        mosdns)
            check_mosdns
            ;;
        daed)
            check_daed
            ;;
    esac

    printf '%s\n' ""
    log "检查完成：本脚本仅检测，不会执行更新"
}

main "$@"
