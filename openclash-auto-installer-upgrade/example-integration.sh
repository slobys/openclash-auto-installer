#!/bin/bash
# 智能网络层集成示例
# 展示如何将智能网络层集成到现有脚本中

set -Eeuo pipefail

echo "========================================"
echo "OpenClash 智能网络层集成示例"
echo "========================================"
echo ""

# 1. 展示目录结构
echo "1. 📁 项目目录结构:"
tree -I '*.git*' -L 3 2>/dev/null || find . -type f -name "*.sh" -o -name "*.conf" | sort | sed 's|^\./||'
echo ""

# 2. 展示如何集成智能下载
echo "2. 📥 集成智能下载到现有脚本:"
cat <<'EOF'
# ============ 原脚本代码 ============
# 简单下载函数
download_file() {
    curl -fsSL "$1" -o "$2" || return 1
}

# ============ 集成后代码 ============
# 导入智能网络层
LIB_DIR="/path/to/lib"
source "$LIB_DIR/error.sh"
source "$LIB_DIR/download.sh"

# 设置错误处理
set_error_trap "$(basename "$0")"
setup_error_logging

# 使用智能下载
download_file() {
    # 原调用: curl -fsSL "$1" -o "$2"
    # 新调用:
    smart_download --urls "$1" \
                   --output "$2" \
                   --retries 3 \
                   --timeout 30 \
                   --cache
}
EOF
echo ""

# 3. 展示 passwall.sh 集成示例
echo "3. 🔑 集成公钥下载 (passwall.sh 示例):"
cat <<'EOF'
# ============ 原代码 ============
KEY_URL="https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub"
wget -qO passwall.pub "$KEY_URL" || die "下载 PassWall 公钥失败"

# ============ 集成后代码 ============
# 导入库
source "$LIB_DIR/download.sh"

# 智能下载公钥
download_pubkey "passwall" "/tmp/passwall.pub" || {
    log_warn "公钥下载失败，使用临时公钥继续"
    # 生成临时公钥逻辑
}
EOF
echo ""

# 4. 展示错误处理集成
echo "4. 🚨 集成错误处理:"
cat <<'EOF'
# ============ 原代码 ============
if [ $? -ne 0 ]; then
    echo "错误: 操作失败"
    exit 1
fi

# ============ 集成后代码 ============
# 在脚本开头
source "$LIB_DIR/error.sh"
set_error_trap "脚本名称"
setup_error_logging "/tmp/脚本名.log"

# 检查环境
check_environment || graceful_exit 1 "环境检查失败"

# 危险操作前确认
confirm_action "确定继续吗?" "yes" || graceful_exit 0 "用户取消"

# 错误自动处理（通过trap）
# 不再需要手动检查 $?
EOF
echo ""

# 5. 展示缓存使用
echo "5. 💾 使用缓存功能:"
cat <<'EOF'
# 启用缓存
export ENABLE_CACHE=1
export CACHE_DIR="/tmp/openclash-cache"

# 下载时自动缓存
smart_download --urls "https://example.com/file.tar.gz" \
               --output "/tmp/file.tar.gz" \
               --cache

# 离线模式
export OFFLINE_MODE=1
# 智能下载会优先使用缓存

# 管理缓存
source "$LIB_DIR/cache.sh"
cache_stats          # 查看统计
list_cache detailed  # 列出缓存
clean_cache "*" 7    # 清理7天前缓存
EOF
echo ""

# 6. 展示网络诊断
echo "6. 🌐 使用网络诊断:"
cat <<'EOF'
# 网络诊断
source "$LIB_DIR/network.sh"

# 检查网络
test_basic_connectivity || {
    log_warn "网络连接异常"
    # 尝试修复或使用离线模式
}

# 测试关键服务
test_service_connectivity

# 生成网络报告
generate_network_report "/tmp/network-report.txt"
EOF
echo ""

# 7. 迁移工具
echo "7. 🛠️ 自动迁移工具 (计划中):"
cat <<'EOF'
计划开发迁移脚本，自动将现有脚本升级为智能网络层版本：
1. 识别下载操作 (curl, wget)
2. 替换为 smart_download
3. 添加错误处理
4. 集成缓存支持
5. 添加网络诊断

# 使用迁移工具
./tools/migrate.sh old_script.sh new_script.sh
EOF
echo ""

# 8. 环境变量参考
echo "8. ⚙️ 环境变量参考:"
cat <<'EOF'
# 网络相关
USE_MIRROR=jsdelivr        # 指定镜像源
OFFLINE_MODE=1             # 离线模式
ENABLE_CACHE=1             # 启用缓存
CACHE_DIR=/path/to/cache   # 缓存目录

# 调试相关
DEBUG=1                    # 调试模式
LOG_LEVEL=DEBUG            # 日志级别
FORCE_YES=1                # 跳过确认

# 下载相关
MAX_RETRIES=5              # 最大重试次数
TIMEOUT=60                 # 超时时间
DOWNLOAD_TIMEOUT=30        # 下载超时

# 代理设置
http_proxy=http://proxy:port
https_proxy=http://proxy:port
HTTP_PROXY=http://proxy:port
HTTPS_PROXY=http://proxy:port
no_proxy=localhost,127.0.0.1
EOF
echo ""

# 9. 快速开始
echo "9. 🚀 快速开始:"
cat <<'EOF'
# 克隆智能网络层
git clone https://github.com/slobys/openclash-auto-installer.git
cd openclash-auto-installer

# 查看升级示例
cat example-integration.sh

# 测试智能下载
source lib/download.sh
smart_download --urls "https://example.com" --output /tmp/test.html

# 运行网络诊断
./scripts/network-diagnose.sh --quick

# 管理缓存
./scripts/cache-manager.sh stats
EOF
echo ""

echo "========================================"
echo "集成完成!"
echo "智能网络层特性:"
echo "✅ 多源备用下载"
echo "✅ 自动缓存管理"
echo "✅ 网络诊断与恢复"
echo "✅ 详细错误报告"
echo "✅ 离线模式支持"
echo "✅ 优雅错误处理"
echo "========================================"