#!/bin/bash
# 简易智能网络层部署脚本
# 只需3步完成部署

set -e

echo "🚀 OpenClash 智能网络层一键部署"
echo "================================="
echo ""

# 步骤1：检查环境
echo "1. 检查环境..."
if ! command -v git >/dev/null 2>&1; then
    echo "❌ 请先安装 git"
    exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
    echo "❌ 请先安装 curl"
    exit 1
fi
echo "✅ 环境检查通过"

# 步骤2：克隆或更新项目
echo ""
echo "2. 准备项目..."
if [ ! -d "openclash-auto-installer" ]; then
    echo "📥 克隆项目..."
    git clone https://github.com/slobys/openclash-auto-installer.git
    cd openclash-auto-installer
else
    echo "📂 使用现有项目"
    cd openclash-auto-installer
    git pull origin main
fi

# 步骤3：创建智能分支
echo "🌿 创建智能分支..."
git checkout -b feat/smart-network-layer 2>/dev/null || git checkout feat/smart-network-layer

# 步骤4：复制智能网络层文件
echo "📦 复制智能网络层文件..."
echo "   注：智能网络层文件已在本地准备好"

# 创建目录
mkdir -p lib config tools backup

# 复制核心库
cp -r /home/naiyou/.openclaw/one-click-script-engineer/openclash-auto-installer-upgrade/lib/* lib/
cp -r /home/naiyou/.openclaw/one-click-script-engineer/openclash-auto-installer-upgrade/config/* config/

# 复制工具脚本
cp /home/naiyou/.openclaw/one-click-script-engineer/openclash-auto-installer-upgrade/scripts/network-diagnose.sh tools/
cp /home/naiyou/.openclaw/one-click-script-engineer/openclash-auto-installer-upgrade/scripts/cache-manager.sh tools/

# 备份原脚本
cp *.sh backup/ 2>/dev/null || true

# 设置执行权限
chmod +x lib/*.sh tools/*.sh

# 步骤5：更新 menu.sh
echo "🔧 更新 menu.sh..."
if [ -f "menu.sh" ]; then
    # 创建临时文件
    cat > /tmp/update_menu.sh <<'EOF'
#!/bin/bash
FILE="menu.sh"
TEMP="/tmp/menu_temp.sh"

# 在 download_and_run 函数开头添加智能版本检测
sed -e '/^download_and_run() {/,/^}/ {
    /log "下载脚本: \$URL"/i\
    # 优先使用本地智能版本\n    if [ -f "scripts/$SCRIPT_NAME" ]; then\n        log "使用本地智能版本: scripts/$SCRIPT_NAME"\n        sh "scripts/$SCRIPT_NAME" "$@"\n        return\n    elif [ -f "$SCRIPT_NAME-smart.sh" ]; then\n        log "使用本地智能版本: $SCRIPT_NAME-smart.sh"\n        sh "$SCRIPT_NAME-smart.sh" "$@"\n        return\n    fi
}' "$FILE" > "$TEMP" && mv "$TEMP" "$FILE"

echo "menu.sh 更新完成"
EOF
    
    chmod +x /tmp/update_menu.sh
    /tmp/update_menu.sh
fi

# 步骤6：提交更改
echo "💾 提交更改..."
git add -A

# 检查是否有更改
if git diff --cached --quiet; then
    echo "⚠️  没有检测到更改"
else
    git commit -m "feat: 添加智能网络层

- 添加智能下载引擎 (lib/download.sh)
- 添加错误处理框架 (lib/error.sh)  
- 添加镜像源配置 (config/mirrors.conf)
- 更新脚本支持智能功能
- 添加网络诊断和缓存管理工具

智能网络层特性:
✅ 多源备用下载 (GitHub → jsDelivr → ghproxy)
✅ 自动重试和工具切换
✅ 缓存支持和离线模式
✅ 友好错误处理和恢复建议
✅ 网络诊断和镜像选择

解决的核心问题:
🔧 GitHub raw 503 错误 → 自动切换镜像源
🔧 SourceForge 公钥失败 → 多源备用 + 临时公钥
🔧 网络不稳定安装失败 → 自动重试 + 缓存支持"
    
    echo "✅ 更改已提交"
fi

# 步骤7：推送到GitHub
echo "🚀 推送到GitHub..."
if git push -u origin feat/smart-network-layer; then
    echo ""
    echo "🎉 部署成功!"
    echo "================================="
    echo "🔗 GitHub 分支链接:"
    echo "https://github.com/slobys/openclash-auto-installer/tree/feat/smart-network-layer"
    echo ""
    echo "📋 后续步骤:"
    echo "1. 在GitHub上创建Pull Request"
    echo "2. 测试智能网络层功能"
    echo "3. 合并到main分支"
    echo "4. 更新项目文档"
    echo ""
    echo "🛠️  立即测试:"
    echo "  ./tools/network-diagnose.sh"
    echo "  ./lib/download.sh --pubkey passwall"
else
    echo "❌ 推送失败"
    echo "请手动执行: git push -u origin feat/smart-network-layer"
fi

# 返回原目录
cd - >/dev/null 2>&1

echo ""
echo "✨ 部署脚本执行完成"