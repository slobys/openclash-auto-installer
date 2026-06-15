#!/bin/sh
set -eu

LOCKDIR="/tmp/daed-install.lock"
TMP_ROOT="/tmp/daed-install"
DAED_REPO="daeuniverse/daed"
DAED_RELEASES_API="https://api.github.com/repos/$DAED_REPO/releases?per_page=20"
DAED_RELEASES_PAGE="https://github.com/$DAED_REPO/releases"
LUCI_DAED_REPO="QiuSimons/luci-app-daed"
LUCI_DAED_API="https://api.github.com/repos/$LUCI_DAED_REPO/releases/latest"
LUCI_DAED_RELEASES_PAGE="https://github.com/$LUCI_DAED_REPO/releases/latest"
DAED_BIN="/usr/bin/daed"
DAED_SHARE="/usr/share/daed"
DAED_CONFIG="/etc/daed"
DAED_INIT="/etc/init.d/daed"
SKIP_START="0"
SKIP_LUCI="0"
FORCE_PKG_UPDATE="1"
LOCK_ACQUIRED="0"

cleanup() {
    if [ "$LOCK_ACQUIRED" = "1" ]; then
        rm -rf "$TMP_ROOT"
        rmdir "$LOCKDIR" 2>/dev/null || true
    fi
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

ensure_unzip() {
    command -v unzip >/dev/null 2>&1 && return 0

    if command -v opkg >/dev/null 2>&1; then
        log "安装解压依赖: unzip"
        opkg update || warn "opkg update 失败，将继续尝试安装 unzip"
        opkg install unzip || die "安装 unzip 失败"
    elif command -v apk >/dev/null 2>&1; then
        log "安装解压依赖: unzip"
        apk update || warn "apk update 失败，将继续尝试安装 unzip"
        apk add unzip || die "安装 unzip 失败"
    else
        die "缺少 unzip，且未检测到 opkg 或 apk"
    fi
}

usage() {
    cat <<'EOF_USAGE'
用法:
  sh daed.sh [选项]

选项:
  --skip-start        安装后不启用和启动 daed 服务
  --skip-luci         跳过安装 LuCI DAED 界面
  --skip-pkg-update   跳过 opkg update / apk update
  -h, --help          显示帮助
EOF_USAGE
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --skip-start)
                SKIP_START="1"
                ;;
            --skip-luci)
                SKIP_LUCI="1"
                ;;
            --skip-pkg-update)
                FORCE_PKG_UPDATE="0"
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

detect_pkg_mgr() {
    if command -v opkg >/dev/null 2>&1; then
        printf 'opkg'
    elif command -v apk >/dev/null 2>&1; then
        printf 'apk'
    else
        printf ''
    fi
}

download_url() {
    URL="$1"
    OUT="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --connect-timeout 15 \
            -H "Accept: application/vnd.github+json" \
            -A "openclash-auto-installer" \
            "$URL" -o "$OUT" && return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO "$OUT" --user-agent="openclash-auto-installer" "$URL" && return 0
    fi

    return 1
}

fetch_luci_release_meta() {
    if download_url "$LUCI_DAED_API" "$TMP_ROOT/luci-release.json"; then
        return 0
    fi

    warn "GitHub API 获取 LuCI DAED Release 失败，改用 Release 页面兜底"
    download_url "$LUCI_DAED_RELEASES_PAGE" "$TMP_ROOT/luci-release.html" || return 1
    LUCI_TAG="$(sed -n 's|.*href="/'"$LUCI_DAED_REPO"'/releases/tag/\([^"/?#]*\)".*|\1|p' "$TMP_ROOT/luci-release.html" | head -n1 || true)"
    [ -n "$LUCI_TAG" ] || return 1
    download_url "https://github.com/$LUCI_DAED_REPO/releases/expanded_assets/$LUCI_TAG" "$TMP_ROOT/luci-assets.html" || return 1
}

find_luci_asset_url() {
    PATTERN="$1"

    if [ -f "$TMP_ROOT/luci-release.json" ]; then
        URL="$(sed 's/"browser_download_url"/\
"browser_download_url"/g' "$TMP_ROOT/luci-release.json" |
            sed -n 's/^"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
            grep "$PATTERN" |
            head -n1 || true)"
        if [ -n "$URL" ]; then
            printf '%s\n' "$URL"
            return 0
        fi
    fi

    for HTML in "$TMP_ROOT/luci-assets.html" "$TMP_ROOT/luci-release.html"; do
        [ -f "$HTML" ] || continue
        URL="$(grep -o "/$LUCI_DAED_REPO/releases/download/[^\"'<> ]*" "$HTML" |
            grep "$PATTERN" |
            head -n1 || true)"
        if [ -n "$URL" ]; then
            printf 'https://github.com%s\n' "$URL"
            return 0
        fi
    done

    return 0
}

maybe_update_pkg_index() {
    PKG_MGR="$1"
    [ "$FORCE_PKG_UPDATE" = "1" ] || {
        log "按参数跳过软件源更新"
        return 0
    }

    case "$PKG_MGR" in
        opkg)
            log "刷新 opkg 软件源索引"
            opkg update || warn "opkg update 失败，将继续安装 LuCI DAED Release 包"
            ;;
        apk)
            log "刷新 apk 软件源索引"
            apk update || warn "apk update 失败，将继续安装 LuCI DAED Release 包"
            ;;
    esac
}

install_luci_daed() {
    PKG_MGR="$1"

    if [ "$SKIP_LUCI" = "1" ]; then
        warn "已按参数跳过安装 LuCI DAED 界面"
        return 0
    fi

    if [ -z "$PKG_MGR" ]; then
        warn "未检测到 opkg 或 apk，无法安装 LuCI DAED 界面；daed 后端已安装"
        return 0
    fi

    fetch_luci_release_meta || {
        warn "无法获取 luci-app-daed 最新 Release；daed 后端已安装"
        return 0
    }

    case "$PKG_MGR" in
        opkg)
            LUCI_PATTERN='luci-app-daed_.*_all-openwrt-24\.10\.ipk$'
            I18N_PATTERN='luci-i18n-daed-zh-cn_.*_all-openwrt-24\.10\.ipk$'
            ;;
        apk)
            LUCI_PATTERN='luci-app-daed-.*-openwrt-25\.12\.apk$'
            I18N_PATTERN='luci-i18n-daed-zh-cn-.*-openwrt-25\.12\.apk$'
            ;;
    esac

    LUCI_URL="$(find_luci_asset_url "$LUCI_PATTERN")"
    I18N_URL="$(find_luci_asset_url "$I18N_PATTERN")"
    if [ -z "$LUCI_URL" ] || [ -z "$I18N_URL" ]; then
        warn "上游未发布匹配当前包管理器的 LuCI DAED 包；daed 后端已安装"
        return 0
    fi

    LUCI_PKG="$TMP_ROOT/$(basename "$LUCI_URL")"
    I18N_PKG="$TMP_ROOT/$(basename "$I18N_URL")"
    log "下载 LuCI DAED: $(basename "$LUCI_PKG")"
    download_url "$LUCI_URL" "$LUCI_PKG" || {
        warn "下载 LuCI DAED 包失败；daed 后端已安装"
        return 0
    }
    log "下载 LuCI DAED 中文包: $(basename "$I18N_PKG")"
    download_url "$I18N_URL" "$I18N_PKG" || {
        warn "下载 LuCI DAED 中文包失败；daed 后端已安装"
        return 0
    }

    maybe_update_pkg_index "$PKG_MGR"
    case "$PKG_MGR" in
        opkg)
            opkg install luci-compat luci-lua-runtime zoneinfo-asia ||
                warn "部分 LuCI DAED 依赖安装失败，将继续尝试安装界面包"
            opkg install --force-depends "$LUCI_PKG" "$I18N_PKG" ||
                warn "LuCI DAED 界面安装失败；daed 后端仍可通过 2023 端口使用"
            ;;
        apk)
            apk add luci-compat luci-lua-runtime zoneinfo-asia ||
                warn "部分 LuCI DAED 依赖安装失败，将继续尝试安装界面包"
            apk add --allow-untrusted --force-broken-world "$LUCI_PKG" "$I18N_PKG" ||
                warn "LuCI DAED 界面安装失败；daed 后端仍可通过 2023 端口使用"
            ;;
    esac
}

detect_asset_arch() {
    OPENWRT_ARCH="${DISTRIB_ARCH:-}"
    MACHINE_ARCH="$(uname -m)"
    SOURCE_ARCH="${OPENWRT_ARCH:-$MACHINE_ARCH}"

    case "$SOURCE_ARCH" in
        aarch64_*|aarch64|arm64)
            printf 'arm64'
            ;;
        x86_64|amd64)
            printf 'x86_64'
            ;;
        i386*|i486*|i586*|i686*)
            printf 'x86_32'
            ;;
        mips64el_*|mips64el)
            printf 'mips64le'
            ;;
        mips64_*|mips64)
            printf 'mips64'
            ;;
        mipsel_*|mipsel)
            printf 'mips32le'
            ;;
        mips_*|mips)
            printf 'mips32'
            ;;
        riscv64_*|riscv64)
            printf 'riscv64'
            ;;
        *)
            die "daed 官方暂未提供当前架构的预编译包: OpenWrt=${OPENWRT_ARCH:-unknown}, uname=${MACHINE_ARCH:-unknown}"
            ;;
    esac
}

version_ge_5_17() {
    VERSION="$(uname -r | sed 's/[^0-9.].*$//')"
    MAJOR="${VERSION%%.*}"
    REST="${VERSION#*.}"
    MINOR="${REST%%.*}"

    case "$MAJOR:$MINOR" in
        *[!0-9:]*|:) return 1 ;;
    esac

    [ "$MAJOR" -gt 5 ] || { [ "$MAJOR" -eq 5 ] && [ "$MINOR" -ge 17 ]; }
}

check_kernel_support() {
    version_ge_5_17 || die "dae 需要 Linux 5.17+ 内核，当前内核为 $(uname -r)"

    CONFIG_FILE="$TMP_ROOT/kernel.config"
    if [ -r /proc/config.gz ] && command -v zcat >/dev/null 2>&1; then
        zcat /proc/config.gz > "$CONFIG_FILE" 2>/dev/null || true
    elif [ -r "/boot/config-$(uname -r)" ]; then
        cp "/boot/config-$(uname -r)" "$CONFIG_FILE"
    elif [ -r /boot/config ]; then
        cp /boot/config "$CONFIG_FILE"
    fi

    if [ ! -s "$CONFIG_FILE" ]; then
        warn "无法读取内核配置，不能确认 eBPF/BTF 能力；将继续安装，但 daed 可能无法启动"
        return 0
    fi

    MISSING=""
    for OPTION in \
        CONFIG_BPF \
        CONFIG_BPF_SYSCALL \
        CONFIG_BPF_JIT \
        CONFIG_CGROUPS \
        CONFIG_KPROBES \
        CONFIG_NET_INGRESS \
        CONFIG_NET_EGRESS \
        CONFIG_NET_CLS_ACT \
        CONFIG_BPF_STREAM_PARSER \
        CONFIG_DEBUG_INFO \
        CONFIG_DEBUG_INFO_BTF \
        CONFIG_KPROBE_EVENTS \
        CONFIG_BPF_EVENTS
    do
        grep -q "^${OPTION}=y$" "$CONFIG_FILE" || MISSING="$MISSING ${OPTION}"
    done

    for OPTION in CONFIG_NET_SCH_INGRESS CONFIG_NET_CLS_BPF; do
        grep -Eq "^${OPTION}=(y|m)$" "$CONFIG_FILE" || MISSING="$MISSING ${OPTION}"
    done

    if grep -q '^CONFIG_DEBUG_INFO_REDUCED=y$' "$CONFIG_FILE"; then
        MISSING="$MISSING # CONFIG_DEBUG_INFO_REDUCED is not set"
    fi

    [ -z "$MISSING" ] || die "当前内核缺少 daed 所需能力:$MISSING"
}

find_latest_tag() {
    RELEASES_JSON="$TMP_ROOT/releases.json"
    RELEASES_HTML="$TMP_ROOT/releases.html"
    TAG=""

    if download_url "$DAED_RELEASES_API" "$RELEASES_JSON"; then
        TAG="$(sed 's/"tag_name"/\
"tag_name"/g' "$RELEASES_JSON" |
            sed -n 's/^"tag_name"[[:space:]]*:[[:space:]]*"\(v[0-9][^"]*\)".*/\1/p' |
            head -n1 || true)"
    fi

    if [ -z "$TAG" ] && download_url "$DAED_RELEASES_PAGE" "$RELEASES_HTML"; then
        TAG="$(sed -n 's|.*href="/'"$DAED_REPO"'/releases/tag/\(v[0-9][^"/?#]*\)".*|\1|p' "$RELEASES_HTML" |
            head -n1 || true)"
    fi

    [ -n "$TAG" ] || die "无法获取 daed 最新正式版本"
    printf '%s' "$TAG"
}

check_disk_space() {
    AVAILABLE_KB="$(df -k /usr 2>/dev/null | awk 'END {print $4}' || printf 0)"
    case "$AVAILABLE_KB" in
        ''|*[!0-9]*) AVAILABLE_KB=0 ;;
    esac

    if [ "$AVAILABLE_KB" -lt 100000 ]; then
        die "系统 /usr 可用空间不足 100MB，无法安装 daed（程序与规则数据约 85MB）"
    fi

    TMP_AVAILABLE_KB="$(df -k /tmp 2>/dev/null | awk 'END {print $4}' || printf 0)"
    case "$TMP_AVAILABLE_KB" in
        ''|*[!0-9]*) TMP_AVAILABLE_KB=0 ;;
    esac

    if [ "$TMP_AVAILABLE_KB" -lt 130000 ]; then
        die "系统 /tmp 可用空间不足 130MB，无法下载并解压 daed 官方包"
    fi
}

verify_archive() {
    ARCHIVE="$1"
    DIGEST_FILE="$2"

    if ! command -v sha256sum >/dev/null 2>&1; then
        warn "缺少 sha256sum，跳过压缩包校验"
        return 0
    fi

    EXPECTED="$(awk '$3 == "sha256" {print $1; exit}' "$DIGEST_FILE")"
    [ -n "$EXPECTED" ] || die "daed 校验文件中未找到 SHA-256"
    ACTUAL="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
    [ "$EXPECTED" = "$ACTUAL" ] || die "daed 压缩包 SHA-256 校验失败"
}

write_init_script() {
    cat > "$DAED_INIT" <<'EOF_INIT'
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1
CONF="daed"
LOG="/var/log/daed/daed.log"

start_service() {
    config_load "$CONF"

    local enabled listen_addr log_maxbackups log_maxsize
    config_get_bool enabled "config" "enabled" "1"
    [ "$enabled" -eq 1 ] || return 1
    config_get listen_addr "config" "listen_addr" "0.0.0.0:2023"
    config_get log_maxbackups "config" "log_maxbackups" "1"
    config_get log_maxsize "config" "log_maxsize" "5"

    mkdir -p /var/log/daed
    procd_open_instance
    procd_set_param command /usr/bin/daed run
    procd_append_param command --config /etc/daed/
    procd_append_param command --listen "$listen_addr"
    procd_append_param command --logfile "$LOG"
    procd_append_param command --logfile-maxbackups "$log_maxbackups"
    procd_append_param command --logfile-maxsize "$log_maxsize"
    procd_set_param env DAE_LOCATION_ASSET="/usr/share/daed"
    procd_set_param respawn 3600 5 5
    procd_set_param limits nofile="1048576 1048576"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

service_triggers() {
    procd_add_reload_trigger "$CONF"
}
EOF_INIT
    chmod 755 "$DAED_INIT"
}

ensure_luci_config() {
    mkdir -p /etc/config /var/log/daed
    if [ ! -f /etc/config/daed ]; then
        cat > /etc/config/daed <<'EOF_CONFIG'
config daed 'config'
	option enabled '1'
	option listen_addr '0.0.0.0:2023'
	option log_maxbackups '1'
	option log_maxsize '5'
EOF_CONFIG
        chmod 600 /etc/config/daed
    fi
    touch /var/log/daed/daed.log
}

refresh_luci() {
    rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true
    if [ -x /etc/init.d/rpcd ]; then
        /etc/init.d/rpcd restart >/dev/null 2>&1 || warn "rpcd 重启失败"
    fi
}

install_daed() {
    ASSET_ARCH="$1"
    TAG="$2"
    ASSET_NAME="daed-linux-${ASSET_ARCH}.zip"
    RELEASE_BASE="https://github.com/$DAED_REPO/releases/download/$TAG"
    ARCHIVE="$TMP_ROOT/$ASSET_NAME"
    DIGEST="$TMP_ROOT/$ASSET_NAME.dgst"
    EXTRACT_DIR="$TMP_ROOT/extract"
    SOURCE_DIR="$EXTRACT_DIR/daed-linux-${ASSET_ARCH}"

    log "下载 daed $TAG: $ASSET_NAME"
    download_url "$RELEASE_BASE/$ASSET_NAME" "$ARCHIVE" || die "下载 daed 压缩包失败"
    download_url "$RELEASE_BASE/$ASSET_NAME.dgst" "$DIGEST" || die "下载 daed 校验文件失败"
    verify_archive "$ARCHIVE" "$DIGEST"

    mkdir -p "$EXTRACT_DIR"
    unzip -q "$ARCHIVE" -d "$EXTRACT_DIR" || die "解压 daed 压缩包失败"
    [ -f "$SOURCE_DIR/daed-linux-${ASSET_ARCH}" ] || die "压缩包内未找到 daed 程序"
    [ -f "$SOURCE_DIR/geoip.dat" ] || die "压缩包内未找到 geoip.dat"
    [ -f "$SOURCE_DIR/geosite.dat" ] || die "压缩包内未找到 geosite.dat"

    if [ -x "$DAED_INIT" ]; then
        "$DAED_INIT" stop >/dev/null 2>&1 || true
    fi

    mkdir -p "$DAED_SHARE" "$DAED_CONFIG"
    cp "$SOURCE_DIR/daed-linux-${ASSET_ARCH}" "$DAED_BIN"
    cp "$SOURCE_DIR/geoip.dat" "$DAED_SHARE/geoip.dat"
    cp "$SOURCE_DIR/geosite.dat" "$DAED_SHARE/geosite.dat"
    chmod 755 "$DAED_BIN"
    chmod 644 "$DAED_SHARE/geoip.dat" "$DAED_SHARE/geosite.dat"
    write_init_script
    ensure_luci_config
}

main() {
    parse_args "$@"
    need_cmd id
    [ "$(id -u)" -eq 0 ] || die "安装和运行 daed 需要 root 权限"

    if ! mkdir "$LOCKDIR" 2>/dev/null; then
        die "已有另一个 daed 任务正在运行"
    fi
    LOCK_ACQUIRED="1"
    mkdir -p "$TMP_ROOT"

    [ -f /etc/openwrt_release ] || die "未检测到 /etc/openwrt_release，当前环境不像 OpenWrt"
    # shellcheck disable=SC1091
    . /etc/openwrt_release

    need_cmd uname
    need_cmd sed
    need_cmd awk
    need_cmd grep
    need_cmd head
    need_cmd df
    need_cmd cp
    need_cmd chmod
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        die "缺少 curl 或 wget，无法下载 daed"
    fi

    log "检查 daed 运行环境"
    check_kernel_support
    check_disk_space

    ASSET_ARCH="$(detect_asset_arch)"
    PKG_MGR="$(detect_pkg_mgr)"
    LATEST_TAG="$(find_latest_tag)"
    OLD_VER="$("$DAED_BIN" --version 2>/dev/null | awk '{print $NF}' | head -n1 || true)"

    log "系统架构: ${DISTRIB_ARCH:-$(uname -m)}"
    log "匹配 daed 架构: $ASSET_ARCH"
    log "当前已安装版本: ${OLD_VER:-not installed}"
    log "最新正式版本: $LATEST_TAG"

    ensure_unzip
    install_daed "$ASSET_ARCH" "$LATEST_TAG"
    install_luci_daed "$PKG_MGR"
    refresh_luci
    NEW_VER="$("$DAED_BIN" --version 2>/dev/null | awk '{print $NF}' | head -n1 || true)"
    log "安装后版本: ${NEW_VER:-unknown}"

    if [ "$SKIP_START" = "1" ]; then
        warn "已按参数跳过启动；可执行 /etc/init.d/daed enable && /etc/init.d/daed start"
    else
        "$DAED_INIT" enable
        "$DAED_INIT" restart || die "daed 服务启动失败，可执行 logread -e daed 查看日志"
        log "daed 服务已启用并启动"
    fi

    warn "daed 依赖 eBPF/BTF；部分 OpenWrt 固件即使内核版本满足，也可能因内核裁剪而无法运行"
    if [ -f /usr/lib/lua/luci/controller/daed.lua ] || [ -f /usr/share/luci/menu.d/luci-app-daed.json ]; then
        log "LuCI 入口: 服务 -> DAED"
    else
        warn "未检测到 LuCI DAED 界面，可通过 --skip-luci 跳过界面安装或检查软件源依赖"
    fi
    log "Web 面板地址: http://路由器IP:2023"
    log "daed 处理完成"
}

main "$@"
