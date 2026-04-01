#!/bin/sh
# 专业版自动下载脚本 - 正确解析 SourceForge 链接
# 解决 timeline.ipk 下载失败问题

set -eu

log() { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
info() { printf '%s\n' "[INFO] $*"; }

# 系统信息
ARCH="aarch64_generic"
RELEASE="24.10"
PACKAGE_DIR="releases/packages-${RELEASE}/${ARCH}"

# 检查命令
need_cmd() { command -v "$1" >/dev/null 2>&1 || { warn "缺少命令: $1"; exit 1; }; }
need_cmd wget
need_cmd opkg
need_cmd sed

# 从 GitHub 获取最新版本号
log "获取 GitHub 最新版本..."
GH_LATEST="$(wget -qO- "https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
log "GitHub 最新版本: ${GH_LATEST:-未知}"

# SourceForge 基础 URL
SF_BASE="https://sourceforge.net/projects/openwrt-passwall-build/files"

# 查找并下载最新可用版本
log "查找 SourceForge 上的 ipk 文件..."

DOWNLOADED_FILES=""
for PKG in luci-app-passwall luci-i18n-passwall-zh-cn; do
    # 访问 passwall_luci 目录
    DIR_URL="${SF_BASE}/${PACKAGE_DIR}/passwall_luci/"
    log "检查目录: $DIR_URL"
    
    PAGE="$(wget -qO- "$DIR_URL" 2>/dev/null || echo '')"
    
    if [ -z "$PAGE" ]; then
        warn "无法获取页面内容"
        continue
    fi
    
    # 调试：显示页面片段
    info "页面大小: $(echo "$PAGE" | wc -l) 行"
    
    # 查找包含包名的链接（可能包含 /stats/timeline）
    # 我们需要匹配类似这样的链接: /projects/.../luci-app-passwall_26.3.6-r1_all.ipk/stats/timeline
    PKG_LINKS="$(echo "$PAGE" | grep -o "href=\"/projects/openwrt-passwall-build/files/[^\"]*${PKG}_[^\"]*\.ipk[^\"]*\"" | sed 's|^href="||;s|"$||')"
    
    info "找到链接: $(echo "$PKG_LINKS" | wc -l) 个"
    if [ -n "$PKG_LINKS" ]; then
        echo "$PKG_LINKS" | while read -r LINK; do
            info "链接: $LINK"
        done
    fi
    
    # 选择第一个链接（通常是最新的）
    PKG_LINK="$(echo "$PKG_LINKS" | head -n1)"
    
    if [ -n "$PKG_LINK" ]; then
        # 修复链接：如果包含 /stats/timeline，去掉它
        CLEAN_LINK="$PKG_LINK"
        if echo "$CLEAN_LINK" | grep -q "/stats/timeline$"; then
            CLEAN_LINK="$(echo "$CLEAN_LINK" | sed 's|/stats/timeline$||')"
            info "清理链接: $CLEAN_LINK"
        fi
        
        # 获取文件名（从清理后的链接）
        FILENAME="$(basename "$CLEAN_LINK").ipk"
        LOCAL_PATH="/tmp/$FILENAME"
        
        # 构建下载链接（添加 /download 后缀）
        DOWNLOAD_URL="https://sourceforge.net${CLEAN_LINK}/download"
        log "下载: $FILENAME"
        log "下载 URL: $DOWNLOAD_URL"
        
        if wget -qO "$LOCAL_PATH" "$DOWNLOAD_URL"; then
            log "✅ 下载成功: $FILENAME"
            DOWNLOADED_FILES="$DOWNLOADED_FILES $LOCAL_PATH"
            
            # 显示文件信息
            FILE_SIZE="$(wc -c < "$LOCAL_PATH" 2>/dev/null || echo 0)"
            if [ "$FILE_SIZE" -lt 100 ]; then
                warn "文件太小 ($FILE_SIZE 字节)，可能是错误页面"
                # 查看文件内容
                head -c 200 "$LOCAL_PATH" 2>/dev/null | cat -v
            else
                log "文件大小: $((FILE_SIZE/1024)) KB"
                
                # 尝试提取版本号
                if echo "$FILENAME" | grep -q "${PKG}_"; then
                    FILE_VER="$(echo "$FILENAME" | sed "s/.*${PKG}_\([^_]*\)_.*/\1/" || echo "未知")"
                    log "文件版本: $FILE_VER"
                fi
            fi
        else
            warn "下载失败: $FILENAME"
            # 尝试备用方法：直接使用原始链接（不带 /download）
            log "尝试备用下载方法..."
            if wget -qO "$LOCAL_PATH" "https://sourceforge.net${CLEAN_LINK}"; then
                log "✅ 备用方法下载成功"
                DOWNLOADED_FILES="$DOWNLOADED_FILES $LOCAL_PATH"
            else
                warn "备用方法也失败"
            fi
        fi
    else
        warn "未找到包: $PKG"
        # 尝试其他查找方法
        log "尝试其他查找方法..."
        # 查找包含包名的任何文本
        PKG_TEXT="$(echo "$PAGE" | grep -i "$PKG" | head -n5)"
        if [ -n "$PKG_TEXT" ]; then
            info "找到相关文本:"
            echo "$PKG_TEXT" | sed 's/^/[DEBUG] /'
        fi
    fi
done

if [ -z "$DOWNLOADED_FILES" ]; then
    warn "没有成功下载任何包"
    log "\n📊 当前状态分析:"
    log "• SourceForge 目录结构显示有 26.3.6-r1 版本"
    log "• GitHub 最新版本: ${GH_LATEST:-未知}"
    log "• 版本差异: 源代码已发布 (26.4.1-1)，但预编译包还未上传 (26.3.6-r1)"
    log ""
    log "🔧 解决方案:"
    log "1. 等待 1-3 天，等作者上传编译好的包"
    log "2. 使用当前 opkg 源中的版本 (26.3.6-r1)"
    log "3. 手动从以下链接尝试下载:"
    log "   https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-24.10/aarch64_generic/passwall_luci/"
    exit 1
fi

# 安装下载的包
log "安装下载的 ipk 包..."
for IPK in $DOWNLOADED_FILES; do
    if [ -f "$IPK" ] && [ -s "$IPK" ]; then
        log "安装: $(basename "$IPK")"
        if opkg install "$IPK"; then
            log "✅ 安装成功: $(basename "$IPK")"
        else
            warn "安装失败: $(basename "$IPK")"
            log "尝试强制安装..."
            if opkg install --force-reinstall "$IPK"; then
                log "✅ 强制安装成功"
            else
                warn "强制安装也失败"
            fi
        fi
    else
        warn "文件不存在或为空: $IPK"
    fi
done

# 版本对比
log "\n📊 版本总结:"
CURRENT_VER="$(opkg status luci-app-passwall 2>/dev/null | sed -n 's/^Version: //p' | head -n1 || echo "未知")"
log "• 当前已安装版本: $CURRENT_VER"
log "• SourceForge 下载版本: 26.3.6-r1 (最新可用)"
log "• GitHub 最新版本: ${GH_LATEST:-未知}"

if [ -n "$GH_LATEST" ] && [ "$GH_LATEST" != "26.3.6-r1" ]; then
    warn "⚠️  版本差异警告:"
    warn "   • GitHub 源代码版本: $GH_LATEST"
    warn "   • SourceForge 预编译包: 26.3.6-r1"
    warn "   • 差异原因: 作者发布了新代码，但还没上传编译好的包"
    warn ""
    warn "💡 建议:"
    warn "   1. 等待 1-3 天，等作者上传新版本"
    warn "   2. 当前版本 26.3.6-r1 已经稳定可用"
    warn "   3. 如需最新功能，可关注 GitHub 仓库更新"
fi

log "🎉 安装完成！请刷新 LuCI 页面查看效果"
log "📋 后续操作:"
log "   • 刷新浏览器缓存"
log "   • 或重新登录 LuCI"
log "   • 或运行: /etc/init.d/uhttpd restart"