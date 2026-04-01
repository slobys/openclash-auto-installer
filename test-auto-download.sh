#!/bin/sh
# 测试自动下载最新版 ipk 功能
# 直接从 SourceForge 查找并安装

set -eu

log() { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }

# 获取系统信息
[ -f /etc/openwrt_release ] || { warn "未检测到 OpenWrt 系统"; exit 1; }
. /etc/openwrt_release

ARCH="${DISTRIB_ARCH:-}"
REL_RAW="${DISTRIB_RELEASE:-}"
[ -n "$ARCH" ] || { warn "无法识别系统架构"; exit 1; }
[ -n "$REL_RAW" ] || { warn "无法识别系统版本"; exit 1; }

case "$REL_RAW" in
    *SNAPSHOT*)
        RELEASE="${REL_RAW%.*}"
        PACKAGE_DIR="snapshots/packages/$ARCH"
        ;;
    *)
        RELEASE="${REL_RAW%.*}"
        PACKAGE_DIR="releases/packages-$RELEASE/$ARCH"
        ;;
esac

log "系统架构: $ARCH"
log "系统版本: $REL_RAW"
log "包目录: $PACKAGE_DIR"

# 检查必要命令
need_cmd() {
    command -v "$1" >/dev/null 2>&1 || { warn "缺少命令: $1"; exit 1; }
}

need_cmd wget
need_cmd opkg

# 查找并下载最新版 ipk
SF_BASE_URL="https://sourceforge.net/projects/openwrt-passwall-build/files"
SF_URL="${SF_BASE_URL}/${PACKAGE_DIR}/"

log "查找最新版 ipk: $SF_URL"

# 获取 SourceForge 页面
if ! PAGE_CONTENT="$(wget -qO- "$SF_URL" 2>/dev/null)"; then
    warn "无法访问 SourceForge 页面"
    exit 1
fi

# 提取所有 ipk 文件链接
IPK_LINKS="$(echo "$PAGE_CONTENT" | grep -o 'href="/projects/openwrt-passwall-build/files/[^"]*\.ipk/download"' | sed 's|^href="||;s|"/download"$||')"

if [ -z "$IPK_LINKS" ]; then
    warn "未找到 ipk 文件"
    exit 1
fi

# 转换为完整 URL
IPK_LINKS="$(echo "$IPK_LINKS" | sed 's|^/|https://sourceforge.net/|g')"

log "找到 $(echo "$IPK_LINKS" | wc -l) 个 ipk 文件"

# 我们需要的主要包
MAIN_PACKAGES="luci-app-passwall luci-i18n-passwall-zh-cn"
DOWNLOADED_FILES=""

for PKG in $MAIN_PACKAGES; do
    PKG_LINKS="$(echo "$IPK_LINKS" | grep "/${PKG}_" | sort -V | tail -n1)"
    
    if [ -n "$PKG_LINKS" ]; then
        FILENAME="$(basename "$PKG_LINKS" .download)"
        LOCAL_PATH="/tmp/$FILENAME"
        
        log "下载: $FILENAME"
        
        # 下载文件（SourceForge 需要加 /download 后缀）
        if wget -qO "$LOCAL_PATH" "${PKG_LINKS}/download"; then
            log "✅ 下载成功: $FILENAME"
            DOWNLOADED_FILES="$DOWNLOADED_FILES $LOCAL_PATH"
        else
            warn "下载失败: $FILENAME"
        fi
    else
        warn "未找到包: $PKG"
    fi
done

if [ -z "$DOWNLOADED_FILES" ]; then
    warn "没有成功下载任何包"
    exit 1
fi

# 安装下载的包
log "安装下载的 ipk 包..."
for IPK in $DOWNLOADED_FILES; do
    if opkg install "$IPK"; then
        log "✅ 安装成功: $(basename "$IPK")"
    else
        warn "安装失败: $(basename "$IPK")"
    fi
done

log "🎉 自动下载安装完成！"
log "请刷新 LuCI 页面查看新版本"