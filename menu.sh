#!/bin/sh
set -eu

BASE_URL="https://raw.githubusercontent.com/slobys/openclash-auto-installer/master"
TMP_SCRIPT="/tmp/openclash-menu-action.sh"

log() {
    printf '%s\n' "==> $*"
}

die() {
    printf '%s\n' "[ERROR] $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

download_and_run() {
    SCRIPT_NAME="$1"
    shift || true
    URL="$BASE_URL/$SCRIPT_NAME"

    log "下载脚本: $URL"
    curl -fsSL --retry 3 "$URL" -o "$TMP_SCRIPT" || die "下载脚本失败: $SCRIPT_NAME"
    chmod +x "$TMP_SCRIPT"
    sh "$TMP_SCRIPT" "$@"
}

show_menu() {
    cat <<'EOF_MENU'
================ OpenClash 管理菜单 ================
1. 安装 / 更新 OpenClash
2. 只更新 OpenClash 插件
3. 只安装 Meta 内核
4. 卸载 OpenClash
0. 退出
====================================================
EOF_MENU
}

read_from_tty() {
    if [ -r /dev/tty ]; then
        read -r "$1" </dev/tty
    else
        die "当前环境不可交互，请改用先下载再执行，或直接运行 install.sh / uninstall.sh"
    fi
}

main() {
    need_cmd curl

    while true; do
        show_menu
        printf '请输入选项 [0-4]: ' >/dev/tty
        read_from_tty choice

        case "$choice" in
            1)
                download_and_run install.sh
                ;;
            2)
                download_and_run install.sh --plugin-only
                ;;
            3)
                download_and_run install.sh --core-only
                ;;
            4)
                download_and_run uninstall.sh
                ;;
            0)
                log "已退出"
                exit 0
                ;;
            *)
                printf '%s\n' '[WARN] 无效选项，请重新输入'
                ;;
        esac

        printf '\n按回车键返回菜单...' >/dev/tty
        read_from_tty _dummy
        printf '\n'
    done
}

main "$@"
