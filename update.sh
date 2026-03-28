#!/bin/sh
set -eu

SCRIPT_URL="https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/install.sh"
TMP_FILE="/tmp/openclash-auto-update.sh"

log() {
    printf '%s\n' "==> $*"
}

die() {
    printf '%s\n' "[ERROR] $*" >&2
    exit 1
}

command -v curl >/dev/null 2>&1 || die "缺少 curl 命令"

log "下载最新安装/更新脚本"
curl -fsSL --retry 3 "$SCRIPT_URL" -o "$TMP_FILE" || die "下载远程脚本失败"
chmod +x "$TMP_FILE"

log "开始执行更新"
sh "$TMP_FILE" --skip-opkg-update "$@"
