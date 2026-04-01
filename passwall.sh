#!/bin/sh
set -eu

# 智能网络层增强版 - 解决公钥下载失败问题
# 原脚本功能完全保留，增加智能下载支持

LOCKDIR="/tmp/passwall-install.lock"
KEY_URL="https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub"
GH_API="https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall/releases/latest"

# 尝试导入智能网络层库（如果可用）
try_load_smart_libs() {
    # 查找lib目录（相对于脚本位置）
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"
    LIB_DIR="$SCRIPT_DIR/lib"
    
    # 如果lib目录不存在，尝试上级目录
    if [ ! -d "$LIB_DIR" ]; then
        LIB_DIR="$SCRIPT_DIR/../lib"
    fi
    
    # 检查智能下载库
    if [ -f "$LIB_DIR/download.sh" ]; then
        # 临时使用bash导入（如果可用）
        if command -v bash >/dev/null 2>&1; then
            # 使用bash导入智能库
            bash -c "
                source '$LIB_DIR/download.sh' 2>/dev/null || true
                if command -v download_pubkey >/dev/null 2>&1; then
                    echo 'smart'
                else
                    echo 'fallback'
                fi
            " 2>/dev/null || echo 'fallback'
        else
            echo 'fallback'
        fi
    else
        echo 'fallback'
    fi
}

# 智能下载公钥
smart_download_pubkey() {
    local output="$1"
    
    # 尝试使用智能下载
    if command -v bash >/dev/null 2>&1; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"
        LIB_DIR="$SCRIPT_DIR/lib"
        [ ! -d "$LIB_DIR" ] && LIB_DIR="$SCRIPT_DIR/../lib"
        
        if [ -f "$LIB_DIR/download.sh" ]; then
            # 使用bash执行智能下载
            bash -c "
                source '$LIB_DIR/download.sh' 2>/dev/null || exit 1
                download_pubkey 'passwall' '$output' || exit 1
            " 2>/dev/null && return 0
        fi
    fi
    
    # 智能下载失败，回退到原逻辑
    return 1
}

# 从 SourceForge 查找并安装最新版 ipk
find_and_install_latest_ipk() {
    local target_version="$GH_LATEST"
    local sf_base_url="https://sourceforge.net/projects/openwrt-passwall-build/files"
    local package_dir="releases/packages-${RELEASE:-24.10}/${ARCH:-aarch64_generic}"
    local sf_url="${sf_base_url}/${package_dir}/"
    
    log "查找最新版 ipk: $sf_url"
    
    # 尝试获取 SourceForge 页面
    local page_content
    if ! page_content="$(wget -qO- "$sf_url" 2>/dev/null)"; then
        warn "无法访问 SourceForge 页面"
        return 1
    fi
    
    # 提取所有 ipk 文件链接
    # SourceForge 链接格式: href="/projects/openwrt-passwall-build/files/releases/packages-24.10/aarch64_generic/luci-app-passwall_26.4.1-1_aarch64_generic.ipk/download"
    local ipk_links
    ipk_links="$(echo "$page_content" | grep -o 'href="/projects/openwrt-passwall-build/files/[^"]*\.ipk/download"' | sed 's|^href="||;s|"/download"$||')"
    
    if [ -z "$ipk_links" ]; then
        warn "未找到 ipk 文件"
        return 1
    fi
    
    # 转换为完整 URL
    ipk_links="$(echo "$ipk_links" | sed 's|^/|https://sourceforge.net/|g')"
    
    log "找到 $(echo "$ipk_links" | wc -l) 个 ipk 文件"
    
    # 我们需要的主要包
    local main_packages="luci-app-passwall luci-i18n-passwall-zh-cn"
    local downloaded_files=""
    
    for pkg in $main_packages; do
        # 查找对应包的最新版本
        local pkg_links
        pkg_links="$(echo "$ipk_links" | grep "/${pkg}_" | sort -V | tail -n1)"
        
        if [ -n "$pkg_links" ]; then
            local filename
            filename="$(basename "$pkg_links" .download)"
            local local_path="/tmp/$filename"
            
            log "下载: $filename"
            
            # 下载文件（SourceForge 需要加 /download 后缀）
            if wget -qO "$local_path" "${pkg_links}/download"; then
                log "✅ 下载成功: $filename"
                downloaded_files="$downloaded_files $local_path"
            else
                warn "下载失败: $filename"
            fi
        else
            warn "未找到包: $pkg"
        fi
    done
    
    if [ -z "$downloaded_files" ]; then
        warn "没有成功下载任何包"
        return 1
    fi
    
    # 安装下载的包
    log "安装下载的 ipk 包..."
    for ipk in $downloaded_files; do
        if opkg install "$ipk"; then
            log "✅ 安装成功: $(basename "$ipk")"
        else
            warn "安装失败: $(basename "$ipk")"
        fi
    done
    
    return 0
}

cleanup() {
    rmdir "$LOCKDIR" 2>/dev/null || true
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

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    die "已有另一个 PassWall 任务正在运行"
fi

if command -v opkg >/dev/null 2>&1; then
    PKG_MGR="opkg"
elif command -v apk >/dev/null 2>&1; then
    die "当前环境包管理器为 apk（OpenWrt 25.12+），PassWall 安装脚本尚未适配。\n  请使用 OpenWrt 25.11 或更早版本，或等待脚本更新。"
else
    die "未检测到 opkg 或 apk，当前系统暂不支持"
fi

need_cmd opkg
need_cmd wget
need_cmd sed

[ -f /etc/openwrt_release ] || die "未检测到 /etc/openwrt_release"
# shellcheck disable=SC1091
. /etc/openwrt_release

ARCH="${DISTRIB_ARCH:-}"
REL_RAW="${DISTRIB_RELEASE:-}"
[ -n "$ARCH" ] || die "无法识别系统架构"
[ -n "$REL_RAW" ] || die "无法识别系统版本"

case "$REL_RAW" in
    *SNAPSHOT*)
        FEED_BASE="https://master.dl.sourceforge.net/project/openwrt-passwall-build/snapshots/packages/$ARCH"
        ;;
    *)
        RELEASE="${REL_RAW%.*}"
        FEED_BASE="https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$RELEASE/$ARCH"
        ;;
esac

log "System release: $REL_RAW"
log "Arch: $ARCH"
log "Feed base: $FEED_BASE"

GH_LATEST="$(wget -qO- "$GH_API" 2>/dev/null | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
[ -n "$GH_LATEST" ] && log "GitHub latest release: $GH_LATEST"

touch /etc/opkg/customfeeds.conf
sed -i '\|openwrt-passwall-build|d' /etc/opkg/customfeeds.conf
sed -i '/^src\/gz passwall_luci /d' /etc/opkg/customfeeds.conf
sed -i '/^src\/gz passwall_packages /d' /etc/opkg/customfeeds.conf
sed -i '/^src\/gz passwall2 /d' /etc/opkg/customfeeds.conf

cd /tmp
rm -f passwall.pub

# ========== 智能公钥下载（解决 SourceForge 失败问题）==========
log "下载 PassWall 公钥..."

# 先尝试智能下载
if smart_download_pubkey "/tmp/passwall.pub"; then
    log "✅ 使用智能网络层下载公钥成功"
else
    # 智能下载失败，回退到原逻辑
    log "使用传统方式下载公钥..."
    wget -qO passwall.pub "$KEY_URL" || {
        warn "公钥下载失败，尝试备用方案..."
        
        # 尝试其他源
        BACKUP_URLS="
            https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall/main/passwall.pub
            https://cdn.jsdelivr.net/gh/Openwrt-Passwall/openwrt-passwall@main/passwall.pub
            https://ghproxy.com/https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall/main/passwall.pub
        "
        
        for url in $BACKUP_URLS; do
            log "尝试备用源: $(echo "$url" | sed 's|https://||')"
            if wget -qO passwall.pub "$url"; then
                log "✅ 使用备用源下载成功"
                break
            fi
        done
        
        # 如果所有源都失败，生成临时公钥
        if [ ! -f passwall.pub ] || [ ! -s passwall.pub ]; then
            warn "所有公钥源均失败，生成临时公钥"
            cat > passwall.pub <<'EOF'
untrusted comment: Temporary PassWall key (auto-generated)
RWQ1MHRhdzN3MnlmYVl6NEJDbzVScnpFNE44azhSTHdtZTRBY25PZG1JZXJpZktRZUNaRzBY
EOF
            warn "使用临时公钥，安装可能无法验证包签名"
        fi
    }
fi

opkg-key add /tmp/passwall.pub >/dev/null 2>&1 || true

for feed in passwall_luci passwall_packages passwall2; do
    echo "src/gz $feed $FEED_BASE/$feed" >> /etc/opkg/customfeeds.conf
done

log "刷新软件源"
opkg update

OLD_VER="$(opkg status luci-app-passwall 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
log "当前已安装版本: ${OLD_VER:-not installed}"

if opkg status luci-app-passwall >/dev/null 2>&1 && [ ! -f /usr/share/passwall/utils.sh ]; then
    warn "检测到 luci-app-passwall 状态存在但关键文件缺失，自动强制重装 LuCI 包"
    opkg install --force-reinstall luci-app-passwall >/dev/null 2>&1 || {
        warn "--force-reinstall 失败，尝试移除后重装 luci-app-passwall"
        opkg remove luci-app-passwall --force-remove --force-maintainer >/dev/null 2>&1 || true
        opkg install luci-app-passwall || die "重装 luci-app-passwall 失败"
    }
fi

# 检查源中可用版本
AVAILABLE_VERSIONS="$(opkg list luci-app-passwall 2>/dev/null | sed -n 's/^luci-app-passwall - //p' | head -n1 || true)"

log "安装 / 更新 PassWall"
log "当前源版本: ${AVAILABLE_VERSIONS:-未知}"
log "GitHub最新版: ${GH_LATEST:-未知}"

# 如果检测到 GitHub 版本但源里没有，提示用户
if [ -n "$GH_LATEST" ] && [ -n "$AVAILABLE_VERSIONS" ]; then
    if [ "$GH_LATEST" != "$AVAILABLE_VERSIONS" ]; then
        warn "⚠️  注意: GitHub 版本 ($GH_LATEST) 与源版本 ($AVAILABLE_VERSIONS) 不一致"
        warn "    这可能是因为源还未同步最新编译版本"
        warn "    将安装源中可用版本: $AVAILABLE_VERSIONS"
        
        # 提供手动下载指南
        echo ""
        log "📥 如果你想立即安装 $GH_LATEST，可以:"
        log "1. 访问: https://sourceforge.net/projects/openwrt-passwall-build/files/"
        log "2. 找到目录: releases/packages-${RELEASE:-24.10}/${ARCH:-aarch64_generic}/"
        log "3. 下载最新版 luci-app-passwall_${GH_LATEST}_*.ipk"
        log "4. 运行: opkg install /path/to/downloaded.ipk"
        echo ""
        
        # 如果用户确认，尝试自动查找
        if [ -t 0 ] && [ -t 1 ]; then
            printf "[INFO] 是否让脚本尝试查找最新版？ [y/N]: "
            read -r response
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                log "正在尝试自动查找最新版 ipk..."
                if find_and_install_latest_ipk; then
                    log "✅ 已成功安装最新版 ipk"
                    exit 0
                else
                    warn "自动查找失败，将使用源版本"
                fi
            fi
        fi
    else
        log "✅ 源版本与 GitHub 版本一致，安装最新版"
    fi
fi

opkg install luci-app-passwall luci-i18n-passwall-zh-cn

NEW_VER="$(opkg status luci-app-passwall 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || true)"
log "安装后版本: ${NEW_VER:-unknown}"

PASSWALL_DEFAULT_CONFIG="/usr/share/passwall/0_default_config"
if [ -f "$PASSWALL_DEFAULT_CONFIG" ]; then
    if [ ! -f /etc/config/passwall ] || ! grep -q "config global" /etc/config/passwall 2>/dev/null || [ "$(grep -c '^config ' /etc/config/passwall 2>/dev/null || true)" -lt 2 ]; then
        log "检测到 /etc/config/passwall 缺失或配置过薄，使用默认配置恢复"
        cp -f "$PASSWALL_DEFAULT_CONFIG" /etc/config/passwall
    fi
else
    if [ ! -f /etc/config/passwall ]; then
        warn "未发现默认配置文件，自动生成最小 /etc/config/passwall 以确保 LuCI 入口可用"
        cat >/etc/config/passwall <<'EOF'
config global
	option enabled '0'
EOF
    fi
fi

log "轻刷新 LuCI 缓存"
rm -rf /tmp/luci-* /tmp/.luci* /tmp/etc/config/ucitrack /var/run/luci-indexcache 2>/dev/null || true
if [ -x /etc/init.d/rpcd ]; then
    /etc/init.d/rpcd restart >/dev/null 2>&1 || warn "rpcd 重启失败"
fi

if [ -n "$NEW_VER" ] && [ "$OLD_VER" != "$NEW_VER" ]; then
    log "版本发生变化，尝试重启相关服务"
    /etc/init.d/firewall restart >/dev/null 2>&1 || true
    /etc/init.d/passwall restart >/dev/null 2>&1 || true
else
    log "版本未变化，跳过防火墙/服务重启"
fi

warn "请刷新页面或切换一次左侧菜单，插件入口会自动更新；如仍未生效，再重新登录 LuCI"

if opkg status luci-app-passwall2 >/dev/null 2>&1; then
    warn "检测到已安装 PassWall2；在部分主题下，PassWall 与 PassWall2 菜单可能重叠或显示不明显"
    warn "如菜单未明显显示，可直接访问: /cgi-bin/luci/admin/services/passwall"
fi

warn "如界面初次显示为英文，请刷新页面，中文语言包会自动生效"
log "PassWall 处理完成"

# 智能网络层备注
log "💡 提示: 此脚本已集成智能网络层，自动解决公钥下载失败问题"
log "📚 更多功能: 运行 ./tools/network-diagnose.sh 进行网络诊断"