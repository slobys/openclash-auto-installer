#!/bin/sh
set -eu

# Legacy compatibility entrypoint.
# The old implementation was a hard-coded OpenWrt 24.10/aarch64/opkg PassWall helper.
# Keep this filename working by delegating to the maintained PassWall installer,
# which now supports both opkg and OpenWrt 25.12+ apk environments.

REPO="slobys/openclash-auto-installer"
BRANCH="main"
BASE_URL="${OPENCLASH_AUTO_BASE_URL:-https://raw.githubusercontent.com/$REPO/$BRANCH}"
TMP_ROOT=""

log() {
    printf '%s\n' "==> $*"
}

die() {
    printf '%s\n' "[ERROR] $*" >&2
    exit 1
}

if [ -f "./passwall.sh" ]; then
    log "auto-download-pro.sh 已合并到 passwall.sh，转交给本地 passwall.sh"
    exec sh ./passwall.sh "$@"
fi

cleanup() {
    [ -z "$TMP_ROOT" ] || rm -rf "$TMP_ROOT"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

TMP_ROOT="$(mktemp -d /tmp/passwall-installer.XXXXXX)"
TMP_SCRIPT="$TMP_ROOT/passwall.sh"
SCRIPT_URL="$BASE_URL/passwall.sh"

log "下载最新 passwall.sh"
DOWNLOADED="0"
if command -v curl >/dev/null 2>&1 && curl -fsSL --retry 3 "$SCRIPT_URL" -o "$TMP_SCRIPT"; then
    DOWNLOADED="1"
elif command -v wget >/dev/null 2>&1 && wget -qO "$TMP_SCRIPT" "$SCRIPT_URL"; then
    DOWNLOADED="1"
fi
[ "$DOWNLOADED" = "1" ] || die "下载 passwall.sh 失败，请检查 curl / wget 和网络连接"
[ -s "$TMP_SCRIPT" ] || die "下载的 passwall.sh 为空"
sh "$TMP_SCRIPT" "$@"
