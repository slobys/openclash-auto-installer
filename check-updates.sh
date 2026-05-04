#!/bin/sh
set -eu

TMP_ROOT="/tmp/plugin-update-check"
OPENCLASH_API="https://api.github.com/repos/vernesong/OpenClash/releases/latest"
PASSWALL_API="https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall/releases/latest"
PASSWALL2_API="https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall2/releases/latest"
NIKKI_REPO_API="https://api.github.com/repos/nikkinikki-org/OpenWrt-nikki/releases/latest"
SMARTDNS_API="https://api.github.com/repos/pymumu/smartdns/releases/latest"
MOSDNS_API="https://api.github.com/repos/sbwml/luci-app-mosdns/releases/latest"
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
    VER="${VER%%-*}"
    printf '%s' "$VER"
}

fetch_latest_tag_jsonfilter() {
    NAME="$1"
    URL="$2"
    OUT="$TMP_ROOT/$NAME.json"
    curl -fsSL --retry 3 --connect-timeout 15 "$URL" -o "$OUT" || return 1
    jsonfilter -i "$OUT" -e '@.tag_name' 2>/dev/null || true
}

fetch_latest_tag_wget_sed() {
    URL="$1"
    wget -qO- "$URL" 2>/dev/null | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
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

    INSTALLED_NORM="$(normalize_version "$INSTALLED")"
    LATEST_NORM="$(normalize_version "$LATEST")"

    if [ "$INSTALLED_NORM" = "$LATEST_NORM" ]; then
        printf '%s\n' "  状态: 已是最新"
    else
        printf '%s\n' "  状态: 有新版本可更新"
    fi
}

get_installed_opkg_version() {
    PKG="$1"
    opkg status "$PKG" 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true
}

get_installed_apk_version() {
    PKG="$1"
    apk info -a "$PKG" 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true
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
    if [ "$PKG_MGR" != "opkg" ]; then
        print_result "PassWall" "" ""
        printf '%s\n' "  说明: 当前仅在 opkg 环境下检测 PassWall"
        return 0
    fi

    INSTALLED="$(get_installed_opkg_version luci-app-passwall)"
    LATEST="$(fetch_latest_tag_wget_sed "$PASSWALL_API" || true)"
    print_result "PassWall" "$INSTALLED" "$LATEST"
}

check_passwall2() {
    if [ "$PKG_MGR" != "opkg" ]; then
        print_result "PassWall2" "" ""
        printf '%s\n' "  说明: 当前仅在 opkg 环境下检测 PassWall2"
        return 0
    fi

    INSTALLED="$(get_installed_opkg_version luci-app-passwall2)"
    LATEST="$(fetch_latest_tag_wget_sed "$PASSWALL2_API" || true)"
    print_result "PassWall2" "$INSTALLED" "$LATEST"
}

check_smartdns() {
    if [ "$PKG_MGR" = "opkg" ]; then
        INSTALLED="$(get_installed_opkg_version smartdns)"
    else
        INSTALLED="$(get_installed_apk_version smartdns)"
    fi

    LATEST="$(fetch_latest_tag_jsonfilter smartdns "$SMARTDNS_API" || true)"
    print_result "SmartDNS" "$INSTALLED" "$LATEST"
}

check_mosdns() {
    if [ "$PKG_MGR" = "opkg" ]; then
        INSTALLED="$(get_installed_opkg_version mosdns)"
    else
        INSTALLED="$(get_installed_apk_version mosdns)"
    fi

    LATEST="$(fetch_latest_tag_jsonfilter mosdns "$MOSDNS_API" || true)"
    print_result "MosDNS" "$INSTALLED" "$LATEST"
}

check_nikki() {
    if [ "$PKG_MGR" = "opkg" ]; then
        INSTALLED="$(get_installed_opkg_version luci-app-nikki)"
    else
        INSTALLED="$(get_installed_apk_version luci-app-nikki)"
    fi

    LATEST="$(fetch_latest_tag_jsonfilter nikki "$NIKKI_REPO_API" || true)"
    print_result "Nikki" "$INSTALLED" "$LATEST"
    if [ -z "${LATEST:-}" ]; then
        printf '%s\n' "  说明: Nikki 官方安装方式更偏 feed/脚本，GitHub Release 可能不是唯一更新来源"
    fi
}

main() {
    parse_args "$@"

    need_cmd sed
    need_cmd head
    need_cmd curl

    if command -v jsonfilter >/dev/null 2>&1; then
        :
    else
        warn "未检测到 jsonfilter，OpenClash / Nikki / SmartDNS / MosDNS 的最新版本检测可能失败"
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
    esac

    printf '%s\n' ""
    log "检查完成：本脚本仅检测，不会执行更新"
}

main "$@"
