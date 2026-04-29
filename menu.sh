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
  sh menu.sh --check-all-updates
  sh menu.sh --check-updates
  sh menu.sh --check-update-openclash
  sh menu.sh --check-update-passwall
  sh menu.sh --check-update-passwall2
  sh menu.sh --check-update-nikki
  sh menu.sh --check-update-smartdns
  sh menu.sh --openclash
  sh menu.sh --openclash-check-update
  sh menu.sh --openclash-plugin-only
  sh menu.sh --openclash-core-only
  sh menu.sh --openclash-meta-core
  sh menu.sh --openclash-smart-core
  sh menu.sh --passwall
  sh menu.sh --passwall2
  sh menu.sh --nikki
  sh menu.sh --smartdns
  sh menu.sh --uninstall-passwall
  sh menu.sh --uninstall-passwall2
  sh menu.sh --uninstall-nikki
  sh menu.sh --uninstall-smartdns
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
            --check-all-updates)
                NONINTERACTIVE_ACTION="check-all-updates"
                ;;
            --check-updates)
                NONINTERACTIVE_ACTION="check-updates"
                ;;
            --check-update-openclash)
                NONINTERACTIVE_ACTION="check-update-openclash"
                ;;
            --check-update-passwall)
                NONINTERACTIVE_ACTION="check-update-passwall"
                ;;
            --check-update-passwall2)
                NONINTERACTIVE_ACTION="check-update-passwall2"
                ;;
            --check-update-nikki)
                NONINTERACTIVE_ACTION="check-update-nikki"
                ;;
            --check-update-smartdns)
                NONINTERACTIVE_ACTION="check-update-smartdns"
                ;;
            --openclash-check-update)
                NONINTERACTIVE_ACTION="openclash-check-update"
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
            --smartdns)
                NONINTERACTIVE_ACTION="smartdns"
                ;;
            --uninstall-passwall)
                NONINTERACTIVE_ACTION="uninstall-passwall"
                ;;
            --uninstall-passwall2)
                NONINTERACTIVE_ACTION="uninstall-passwall2"
                ;;
            --uninstall-nikki)
                NONINTERACTIVE_ACTION="uninstall-nikki"
                ;;
            --uninstall-smartdns)
                NONINTERACTIVE_ACTION="uninstall-smartdns"
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
    
    # 优先使用本地智能版本
    if [ -f "scripts/$SCRIPT_NAME" ]; then
        log "使用本地智能版本: scripts/$SCRIPT_NAME"
        sh "scripts/$SCRIPT_NAME" "$@"
        return
    elif [ -f "$SCRIPT_NAME-smart.sh" ]; then
        log "使用本地智能版本: $SCRIPT_NAME-smart.sh"
        sh "$SCRIPT_NAME-smart.sh" "$@"
        return
    fi
    
    URL="$BASE_URL/$SCRIPT_NAME"
    FETCH_URL="$URL?ts=$(date +%s)"

    log "下载脚本: $URL"
    curl -fsSL --retry 3 "$FETCH_URL" -o "$TMP_SCRIPT" || die "下载脚本失败: $SCRIPT_NAME"
    chmod +x "$TMP_SCRIPT"
    sh "$TMP_SCRIPT" "$@"
}

show_menu() {
    cat <<'EOF_MENU'
================ 代理插件管理菜单 ================
1. 检查插件更新
2. 安装插件
3. 卸载插件
0. 退出
==================================================
EOF_MENU
}

show_install_menu() {
    cat <<'EOF_INSTALL_MENU'
================ 安装插件 ================
1. 安装 / 更新 OpenClash（自动识别 Meta / Smart）
2. 只更新 OpenClash 插件
3. 只安装 OpenClash 核心（自动识别 Meta / Smart）
4. 只安装 OpenClash 普通 Meta 内核
5. 只安装 OpenClash Smart Meta 内核
6. 安装 / 更新 PassWall
7. 安装 / 更新 PassWall2
8. 安装 / 更新 Nikki
9. 安装 / 更新 SmartDNS
0. 返回上一级
==========================================
EOF_INSTALL_MENU
}

show_uninstall_menu() {
    cat <<'EOF_UNINSTALL_MENU'
================ 卸载插件 ================
1. 卸载 PassWall
2. 卸载 PassWall2
3. 卸载 Nikki
4. 卸载 SmartDNS
5. 卸载 OpenClash
0. 返回上一级
==========================================
EOF_UNINSTALL_MENU
}

show_check_update_menu() {
    cat <<'EOF_CHECK_MENU'
================ 检查插件更新 ================
1. 检查所有插件
2. 检查 OpenClash
3. 检查 PassWall
4. 检查 PassWall2
5. 检查 Nikki
6. 检查 SmartDNS
0. 返回上一级
==============================================
EOF_CHECK_MENU
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
        1|check-updates)
            run_check_update_menu
            ;;
        check-all-updates)
            download_and_run check-updates.sh
            ;;
        check-update-openclash)
            download_and_run check-updates.sh --openclash
            ;;
        check-update-passwall)
            download_and_run check-updates.sh --passwall
            ;;
        check-update-passwall2)
            download_and_run check-updates.sh --passwall2
            ;;
        check-update-nikki)
            download_and_run check-updates.sh --nikki
            ;;
        check-update-smartdns)
            download_and_run check-updates.sh --smartdns
            ;;
        2|install-plugins)
            run_install_menu
            ;;
        3|uninstall-plugins)
            run_uninstall_menu
            ;;
        openclash)
            download_and_run install.sh
            ;;
        openclash-check-update)
            download_and_run install.sh --check-update --skip-opkg-update
            ;;
        openclash-plugin-only)
            download_and_run install.sh --plugin-only
            ;;
        openclash-core-only)
            download_and_run install.sh --core-only
            ;;
        openclash-meta-core)
            download_and_run install.sh --core-only --meta-core --skip-opkg-update
            ;;
        openclash-smart-core)
            download_and_run install.sh --core-only --smart-core --skip-opkg-update
            ;;
        passwall)
            download_and_run passwall.sh
            ;;
        passwall2)
            download_and_run passwall2.sh
            ;;
        nikki)
            download_and_run nikki.sh
            ;;
        smartdns)
            download_and_run smartdns.sh
            ;;
        uninstall-passwall)
            download_and_run uninstall.sh passwall --delete-config
            ;;
        uninstall-passwall2)
            download_and_run uninstall.sh passwall2 --delete-config
            ;;
        uninstall-nikki)
            download_and_run uninstall.sh nikki --delete-config
            ;;
        uninstall-smartdns)
            download_and_run uninstall.sh smartdns --delete-config
            ;;
        uninstall-openclash)
            download_and_run uninstall.sh openclash --delete-config
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

run_check_update_menu() {
    while true; do
        show_check_update_menu
        printf '请输入选项 [0-6]: ' >/dev/tty
        read_from_tty subchoice
        case "$subchoice" in
            1)
                download_and_run check-updates.sh
                ;;
            2)
                download_and_run check-updates.sh --openclash
                ;;
            3)
                download_and_run check-updates.sh --passwall
                ;;
            4)
                download_and_run check-updates.sh --passwall2
                ;;
            5)
                download_and_run check-updates.sh --nikki
                ;;
            6)
                download_and_run check-updates.sh --smartdns
                ;;
            0)
                return 0
                ;;
            *)
                printf '%s\n' '[WARN] 无效选项，请重新输入'
                ;;
        esac
        printf '\n按回车键返回检查插件更新菜单...' >/dev/tty
        read_from_tty _subdummy
        printf '\n'
    done
}

run_install_menu() {
    while true; do
        show_install_menu
        printf '请输入选项 [0-9]: ' >/dev/tty
        read_from_tty subchoice
        case "$subchoice" in
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
                download_and_run install.sh --core-only --meta-core --skip-opkg-update
                ;;
            5)
                download_and_run install.sh --core-only --smart-core --skip-opkg-update
                ;;
            6)
                download_and_run passwall.sh
                ;;
            7)
                download_and_run passwall2.sh
                ;;
            8)
                download_and_run nikki.sh
                ;;
            9)
                download_and_run smartdns.sh
                ;;
            0)
                return 0
                ;;
            *)
                printf '%s\n' '[WARN] 无效选项，请重新输入'
                ;;
        esac
        printf '\n按回车键返回安装插件菜单...' >/dev/tty
        read_from_tty _subdummy
        printf '\n'
    done
}

run_uninstall_menu() {
    while true; do
        show_uninstall_menu
        printf '请输入选项 [0-5]: ' >/dev/tty
        read_from_tty subchoice
        case "$subchoice" in
            1)
                download_and_run uninstall.sh passwall --delete-config
                ;;
            2)
                download_and_run uninstall.sh passwall2 --delete-config
                ;;
            3)
                download_and_run uninstall.sh nikki --delete-config
                ;;
            4)
                download_and_run uninstall.sh smartdns --delete-config
                ;;
            5)
                download_and_run uninstall.sh openclash --delete-config
                ;;
            0)
                return 0
                ;;
            *)
                printf '%s\n' '[WARN] 无效选项，请重新输入'
                ;;
        esac
        printf '\n按回车键返回卸载插件菜单...' >/dev/tty
        read_from_tty _subdummy
        printf '\n'
    done
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
        printf '请输入选项 [0-3]: ' >/dev/tty
        read_from_tty choice
        run_action "$choice"
        printf '\n按回车键返回菜单...' >/dev/tty
        read_from_tty _dummy
        printf '\n'
    done
}

main "$@"
