#!/bin/sh
set -eu

BASE_URL="https://raw.githubusercontent.com/slobys/openclash-auto-installer/main"
TMP_SCRIPT="/tmp/openclash-menu-action.sh"
NONINTERACTIVE_ACTION=""

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

usage() {
    cat <<'EOF_USAGE'
用法:
  sh menu.sh
  sh menu.sh --openclash
  sh menu.sh --openclash-plugin-only
  sh menu.sh --openclash-core-only
  sh menu.sh --openclash-meta-core
  sh menu.sh --openclash-smart-core
  sh menu.sh --passwall
  sh menu.sh --passwall2
  sh menu.sh --nikki
  sh menu.sh --uninstall-openclash

说明:
  不带参数时进入交互菜单
  带参数时直接执行对应动作，适合非交互环境
EOF_USAGE
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --openclash)
                NONINTERACTIVE_ACTION="openclash"
                ;;
            --openclash-plugin-only)
                NONINTERACTIVE_ACTION="openclash-plugin-only"
                ;;
            --openclash-core-only)
                NONINTERACTIVE_ACTION="openclash-core-only"
                ;;
            --openclash-meta-core)
                NONINTERACTIVE_ACTION="openclash-meta-core"
                ;;
            --openclash-smart-core)
                NONINTERACTIVE_ACTION="openclash-smart-core"
                ;;
            --passwall)
                NONINTERACTIVE_ACTION="passwall"
                ;;
            --passwall2)
                NONINTERACTIVE_ACTION="passwall2"
                ;;
            --nikki)
                NONINTERACTIVE_ACTION="nikki"
                ;;
            --uninstall-openclash)
                NONINTERACTIVE_ACTION="uninstall-openclash"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "未知参数: $1"
                ;;
        esac
        shift
    done
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
================ 代理插件管理菜单 ================
1. 安装 / 更新 OpenClash（自动识别 Meta / Smart）
2. 只更新 OpenClash 插件
3. 只安装 OpenClash 核心（自动识别 Meta / Smart）
4. 只安装 OpenClash 普通 Meta 内核
5. 只安装 OpenClash Smart Meta 内核
6. 安装 / 更新 PassWall
7. 安装 / 更新 PassWall2
8. 安装 / 更新 Nikki
9. 卸载 OpenClash
0. 退出
==================================================
EOF_MENU
}

read_from_tty() {
    if [ -r /dev/tty ]; then
        read -r "$1" </dev/tty
    else
        die "当前环境不可交互，请改用非交互参数模式"
    fi
}

run_action() {
    action="$1"
    case "$action" in
        1|openclash)
            download_and_run install.sh
            ;;
        2|openclash-plugin-only)
            download_and_run install.sh --plugin-only
            ;;
        3|openclash-core-only)
            download_and_run install.sh --core-only
            ;;
        4|openclash-meta-core)
            download_and_run install.sh --core-only --meta-core --skip-opkg-update
            ;;
        5|openclash-smart-core)
            download_and_run install.sh --core-only --smart-core --skip-opkg-update
            ;;
        6|passwall)
            download_and_run passwall.sh
            ;;
        7|passwall2)
            download_and_run passwall2.sh
            ;;
        8|nikki)
            download_and_run nikki.sh
            ;;
        9|uninstall-openclash)
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
}

main() {
    parse_args "$@"
    need_cmd curl

    if [ -n "$NONINTERACTIVE_ACTION" ]; then
        run_action "$NONINTERACTIVE_ACTION"
        exit 0
    fi

    while true; do
        show_menu
        printf '请输入选项 [0-9]: ' >/dev/tty
        read_from_tty choice
        run_action "$choice"
        printf '\n按回车键返回菜单...' >/dev/tty
        read_from_tty _dummy
        printf '\n'
    done
}

main "$@"
