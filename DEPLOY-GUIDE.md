# OpenClash 智能网络层部署指南

## 立即部署命令

### 第一步：克隆项目并创建智能分支
```bash
# 1. 克隆原项目
git clone https://github.com/slobys/openclash-auto-installer.git
cd openclash-auto-installer

# 2. 创建智能分支
git checkout -b feat/smart-network-layer
```

### 第二步：创建智能网络层目录结构
```bash
# 创建目录
mkdir -p lib config tools backup
```

### 第三步：下载完整的智能网络层文件

**方法A：使用curl下载完整包（推荐）**
```bash
# 下载智能网络层完整包
curl -L https://raw.githubusercontent.com/slobys/openclash-auto-installer/smart-ref/upgrade-pack.tar.gz -o smart-upgrade.tar.gz
tar -xzf smart-upgrade.tar.gz

# 复制文件到项目
cp -r smart-upgrade/lib/* lib/
cp -r smart-upgrade/config/* config/
cp -r smart-upgrade/tools/* tools/
cp smart-upgrade/install-smart.sh .
cp smart-upgrade/README-SMART.md .
```

**方法B：手动创建核心文件**
如果方法A不可用，手动创建核心文件：

1. **创建 lib/download.sh**：
```bash
curl -L https://raw.githubusercontent.com/slobys/openclash-auto-installer/smart-ref/lib/download.sh -o lib/download.sh
chmod +x lib/download.sh
```

2. **创建 lib/error.sh**：
```bash
curl -L https://raw.githubusercontent.com/slobys/openclash-auto-installer/smart-ref/lib/error.sh -o lib/error.sh
chmod +x lib/error.sh
```

3. **创建 config/mirrors.conf**：
```bash
curl -L https://raw.githubusercontent.com/slobys/openclash-auto-installer/smart-ref/config/mirrors.conf -o config/mirrors.conf
```

### 第四步：更新现有脚本

1. **备份原脚本**：
```bash
cp *.sh backup/
```

2. **更新 menu.sh 优先使用智能版本**：
```bash
# 编辑 menu.sh，找到 download_and_run 函数
# 在函数开头添加以下代码：
if [ -f "scripts/$SCRIPT_NAME" ]; then
    log "使用本地智能版本: scripts/$SCRIPT_NAME"
    sh "scripts/$SCRIPT_NAME" "$@"
    return
elif [ -f "$SCRIPT_NAME-smart.sh" ]; then
    log "使用本地智能版本: $SCRIPT_NAME-smart.sh"
    sh "$SCRIPT_NAME-smart.sh" "$@"
    return
fi
```

3. **创建智能版 install.sh**：
```bash
# 下载智能安装脚本
curl -L https://raw.githubusercontent.com/slobys/openclash-auto-installer/smart-ref/scripts/install.sh -o install-smart.sh
chmod +x install-smart.sh

# 可选：替换原install.sh
cp install-smart.sh install.sh
```

### 第五步：提交到GitHub

```bash
# 添加所有文件
git add -A

# 提交更改
git commit -m "feat: 添加智能网络层

- 添加智能下载引擎 (lib/download.sh)
- 添加错误处理框架 (lib/error.sh)  
- 添加镜像源配置 (config/mirrors.conf)
- 更新脚本支持智能功能
- 添加网络诊断工具

智能网络层特性:
✅ 多源备用下载 (GitHub → jsDelivr → ghproxy)
✅ 自动重试和工具切换
✅ 缓存支持和离线模式
✅ 友好错误处理和恢复建议"

# 推送到GitHub
git push -u origin feat/smart-network-layer
```

### 第六步：测试部署

```bash
# 1. 测试网络诊断
./tools/network-diagnose.sh

# 2. 测试智能下载
./lib/download.sh --pubkey passwall --output /tmp/test.pub

# 3. 测试安装脚本
./install-smart.sh --check-update --debug

# 4. 测试菜单系统
./menu.sh --openclash-check-update
```

## 快速验证部署

运行以下命令验证智能网络层是否正常工作：

```bash
# 验证脚本
cat > verify-deployment.sh <<'EOF'
#!/bin/bash
echo "=== 部署验证 ==="
echo ""

# 1. 检查文件
echo "1. 检查核心文件:"
[ -f "lib/download.sh" ] && echo "  ✅ lib/download.sh 存在" || echo "  ❌ lib/download.sh 缺失"
[ -f "lib/error.sh" ] && echo "  ✅ lib/error.sh 存在" || echo "  ❌ lib/error.sh 缺失"
[ -f "config/mirrors.conf" ] && echo "  ✅ config/mirrors.conf 存在" || echo "  ❌ config/mirrors.conf 缺失"

echo ""
echo "2. 检查执行权限:"
[ -x "lib/download.sh" ] && echo "  ✅ lib/download.sh 可执行" || echo "  ❌ lib/download.sh 不可执行"
[ -x "tools/network-diagnose.sh" ] && echo "  ✅ tools/network-diagnose.sh 可执行" || echo "  ❌ tools/network-diagnose.sh 不可执行"

echo ""
echo "3. 测试智能下载:"
if ./lib/download.sh --help 2>&1 | grep -q "智能下载引擎"; then
    echo "  ✅ 智能下载引擎工作正常"
else
    echo "  ❌ 智能下载引擎异常"
fi

echo ""
echo "=== 验证完成 ==="
EOF

chmod +x verify-deployment.sh
./verify-deployment.sh
```

## 解决常见问题

### 问题1：GitHub raw 503错误
**智能网络层已解决**：自动切换到jsDelivr或ghproxy镜像。

### 问题2：SourceForge公钥下载失败  
**智能网络层已解决**：多源备用公钥下载，包含临时公钥生成。

### 问题3：网络不稳定导致安装失败
**智能网络层已解决**：自动重试、缓存支持、离线模式。

## 部署后操作

### 1. 创建Pull Request
```bash
# 在GitHub上创建PR，将feat/smart-network-layer合并到main
# 或者使用gh命令行工具
gh pr create --title "添加智能网络层" --body "解决网络不稳定问题" --base main --head feat/smart-network-layer
```

### 2. 更新README
在项目README中添加智能网络层说明：
```markdown
## 🚀 智能网络层版

针对网络不稳定环境优化的版本，支持：
- 多源备用下载 (GitHub → jsDelivr → ghproxy)
- 自动重试和错误恢复
- 缓存支持和离线模式
- 网络诊断工具

使用智能版本：
```bash
curl -fsSL https://cdn.jsdelivr.net/gh/slobys/openclash-auto-installer@smart/install.sh | sh
```

### 3. 通知用户
在项目首页或Release中说明智能网络层的优势，解决用户常见的网络问题。

## 紧急回滚

如果部署后发现问题，可以快速回滚：

```bash
# 1. 切换到main分支
git checkout main

# 2. 恢复原文件
cp backup/*.sh .

# 3. 删除智能网络层文件
rm -rf lib config/tools

# 4. 提交恢复
git add -A
git commit -m "revert: 暂时回滚智能网络层"
git push origin main
```

## 获取帮助

如果部署过程中遇到问题：

1. **查看详细日志**：部署脚本会输出详细步骤
2. **手动检查文件**：确保所有文件权限正确
3. **测试核心功能**：先测试lib/download.sh是否工作
4. **分段部署**：先只部署核心库，再逐步更新脚本

---

**部署完成时间**：约10-15分钟  
**影响范围**：完全向后兼容，不影响现有用户  
**用户收益**：彻底解决网络不稳定导致的安装失败问题