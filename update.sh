#!/bin/sh
set -eu

BASE_URL="${OPENCLASH_AUTO_BASE_URL:-https://raw.githubusercontent.com/slobys/openclash-auto-installer/main}"
SCRIPT_URL="$BASE_URL/install.sh"
TMP_ROOT=""

log() {
    printf '%s\n' "==> $*"
}

die() {
    printf '%s\n' "[ERROR] $*" >&2
    exit 1
}

cleanup() {
    [ -z "$TMP_ROOT" ] || rm -rf "$TMP_ROOT"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

download_script() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 "$SCRIPT_URL" -o "$TMP_FILE" && return 0
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -qO "$TMP_FILE" "$SCRIPT_URL" && return 0
    fi
    return 1
}

TMP_ROOT="$(mktemp -d /tmp/openclash-auto-update.XXXXXX)"
TMP_FILE="$TMP_ROOT/install.sh"
log "下载最新安装/更新脚本"
download_script || die "下载远程脚本失败，请检查 curl / wget 和网络连接"
[ -s "$TMP_FILE" ] || die "下载的安装/更新脚本为空"

if [ "${1:-}" = "--check" ] || [ "${1:-}" = "--check-update" ]; then
    shift
    log "开始检查是否有新版本"
    sh "$TMP_FILE" --check-update --skip-pkg-update "$@"
else
    log "开始执行更新"
    sh "$TMP_FILE" --skip-pkg-update "$@"
fi
