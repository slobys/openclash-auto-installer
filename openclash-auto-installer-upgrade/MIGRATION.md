# 迁移指南：从原版升级到智能网络层版

本指南帮助你将现有的 `openclash-auto-installer` 项目升级到智能网络层增强版。

## 📋 迁移前准备

### 1. 备份原项目
```bash
# 克隆原项目（如果还没有）
git clone https://github.com/slobys/openclash-auto-installer.git
cd openclash-auto-installer

# 创建备份分支
git checkout -b backup-original
git push origin backup-original

# 或本地备份
cp -r openclash-auto-installer openclash-auto-installer-backup
```

### 2. 检查原项目状态
```bash
# 查看主要脚本
ls -la *.sh

# 测试原脚本功能
sh install.sh --check-update
sh passwall.sh --help
```

### 3. 准备智能网络层文件
你可以选择：
- **方式A**：直接使用本仓库的完整升级版
- **方式B**：只集成核心库到原项目

## 🚀 方式A：完整替换（推荐）

### 步骤1：下载智能网络层版
```bash
# 下载升级包
curl -L https://github.com/slobys/openclash-auto-installer/archive/refs/heads/smart.zip -o smart-upgrade.zip
unzip smart-upgrade.zip

# 或使用git（如果有smart分支）
git fetch origin smart:smart
git checkout smart
```

### 步骤2：替换文件结构
```bash
# 备份原文件
mkdir -p backup
cp *.sh backup/

# 复制智能网络层文件
cp -r openclash-auto-installer-smart/lib .
cp -r openclash-auto-installer-smart/scripts/*.sh .
cp openclash-auto-installer-smart/config/mirrors.conf config/
cp openclash-auto-installer-smart/README.md README-SMART.md

# 重命名脚本（可选，保持兼容）
cp scripts/install.sh install-smart.sh
cp scripts/network-diagnose.sh tools/
cp scripts/cache-manager.sh tools/
```

### 步骤3：测试升级版
```bash
# 测试智能安装
sh install-smart.sh --check-update

# 测试网络诊断
sh tools/network-diagnose.sh --quick

# 测试缓存管理
sh tools/cache-manager.sh stats
```

### 步骤4：更新入口脚本
更新 `menu.sh` 以使用智能版本：

```bash
# 在 menu.sh 中找到类似这样的代码：
download_and_run() {
    SCRIPT_NAME="$1"
    URL="$BASE_URL/$SCRIPT_NAME"
    curl -fsSL --retry 3 "$URL" -o "$TMP_SCRIPT"
    sh "$TMP_SCRIPT" "$@"
}

# 替换为智能版本：
download_and_run() {
    SCRIPT_NAME="$1"
    
    # 优先使用本地智能版本
    if [ -f "scripts/$SCRIPT_NAME" ]; then
        log "使用本地智能版本: scripts/$SCRIPT_NAME"
        sh "scripts/$SCRIPT_NAME" "$@"
    elif [ -f "$SCRIPT_NAME-smart.sh" ]; then
        log "使用本地智能版本: $SCRIPT_NAME-smart.sh"
        sh "$SCRIPT_NAME-smart.sh" "$@"
    else
        # 回退到远程下载
        URL="$BASE_URL/$SCRIPT_NAME"
        log "下载脚本: $URL"
        curl -fsSL --retry 3 "$URL" -o "$TMP_SCRIPT" || die "下载脚本失败"
        sh "$TMP_SCRIPT" "$@"
    fi
}
```

## 🛠️ 方式B：渐进式集成（保持兼容）

### 步骤1：添加核心库
```bash
# 创建库目录
mkdir -p lib

# 复制核心库文件
cp smart-upgrade/lib/download.sh lib/
cp smart-upgrade/lib/error.sh lib/
cp smart-upgrade/lib/network.sh lib/
cp smart-upgrade/lib/cache.sh lib/

# 设置执行权限
chmod +x lib/*.sh
```

### 步骤2：改造 install.sh
```bash
# 备份原脚本
cp install.sh install.sh.orig

# 在 install.sh 开头添加：
#!/bin/bash
set -Eeuo pipefail

# 导入智能网络层库
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
[ -f "$LIB_DIR/download.sh" ] && source "$LIB_DIR/download.sh"
[ -f "$LIB_DIR/error.sh" ] && source "$LIB_DIR/error.sh"

# 设置错误处理（如果可用）
if command -v set_error_trap >/dev/null 2>&1; then
    set_error_trap "$(basename "$0")"
fi
```

### 步骤3：替换下载逻辑
查找并替换原脚本中的下载代码：

**原代码：**
```bash
# 下载文件
curl -fsSL --retry 3 "$URL" -o "$OUTPUT" || die "下载失败"
```

**新代码：**
```bash
# 智能下载（如果库存在）
if command -v smart_download >/dev/null 2>&1; then
    smart_download --urls "$URL" \
                   --output "$OUTPUT" \
                   --retries 3 \
                   --timeout 30 \
                   --cache
else
    # 回退到原逻辑
    curl -fsSL --retry 3 "$URL" -o "$OUTPUT" || die "下载失败"
fi
```

### 步骤4：改造 passwall.sh（公钥下载）
**原代码：**
```bash
wget -qO passwall.pub "$KEY_URL" || die "下载 PassWall 公钥失败"
```

**新代码：**
```bash
# 智能下载公钥
if command -v download_pubkey >/dev/null 2>&1; then
    download_pubkey "passwall" "/tmp/passwall.pub" || {
        log_warn "公钥下载失败，使用临时公钥继续"
        # 生成临时公钥逻辑
    }
else
    wget -qO passwall.pub "$KEY_URL" || die "下载 PassWall 公钥失败"
fi
```

### 步骤5：添加智能功能开关
在脚本开头添加配置：

```bash
# 智能网络层配置
ENABLE_SMART_FEATURES="${ENABLE_SMART:-1}"  # 默认启用
CACHE_DIR="${CACHE_DIR:-/tmp/openclash-cache}"
USE_MIRROR="${USE_MIRROR:-auto}"  # auto, github, jsdelivr, ghproxy

# 根据开关选择逻辑
if [ "$ENABLE_SMART_FEATURES" = "1" ] && [ -f "$LIB_DIR/download.sh" ]; then
    source "$LIB_DIR/download.sh"
    source "$LIB_DIR/error.sh"
    SMART_MODE="1"
else
    SMART_MODE="0"
fi
```

## 🔄 自动迁移脚本

我们提供了一个自动迁移脚本（计划中）：

```bash
#!/bin/bash
# migrate.sh - 自动迁移脚本到智能网络层

SOURCE="$1"
TARGET="${2:-${SOURCE}.smart}"

echo "迁移: $SOURCE -> $TARGET"

# 1. 复制原文件
cp "$SOURCE" "$TARGET"

# 2. 添加库导入
sed -i '2i# 导入智能网络层库\nLIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"\n[ -f "$LIB_DIR/download.sh" ] \&\& source "$LIB_DIR/download.sh"' "$TARGET"

# 3. 替换curl下载
sed -i 's/curl -fsSL --retry [0-9]\+ "\([^"]*\)" -o "\([^"]*\)" \|\| die/smart_download --urls "\1" --output "\2" --retries 3 --timeout 30 --cache ||/' "$TARGET"

# 4. 替换wget下载
sed -i 's/wget -qO "\([^"]*\)" "\([^"]*\)" \|\| die/download_pubkey "passwall" "\1" ||/' "$TARGET"

echo "迁移完成: $TARGET"
echo "请手动检查并测试迁移结果"
```

## 🧪 迁移后测试

### 测试清单
- [ ] **网络正常环境**：所有功能正常工作
- [ ] **网络异常环境**：优雅降级，提供有用错误信息
- [ ] **离线模式**：使用缓存正常工作
- [ ] **缓存功能**：文件正确缓存和重用
- [ ] **错误处理**：友好错误信息，恢复建议
- [ ] **向后兼容**：原参数和功能保持不变
- [ ] **性能测试**：无明显性能下降

### 测试命令
```bash
# 1. 基本功能测试
sh install.sh --check-update
sh install.sh --plugin-only --skip-opkg-update

# 2. 网络异常测试（模拟）
export http_proxy=invalid:8080  # 设置错误代理
sh install.sh --check-update  # 应该显示友好错误

# 3. 离线模式测试
export OFFLINE_MODE=1
sh install.sh --check-update  # 应该使用缓存或提示离线

# 4. 缓存测试
export ENABLE_CACHE=1
sh install.sh --check-update  # 第一次下载
sh install.sh --check-update  # 第二次应该使用缓存

# 5. 错误处理测试
rm -f /usr/bin/curl 2>/dev/null  # 临时移除curl（测试后恢复）
sh install.sh --check-update  # 应该自动切换到wget
```

## 📈 性能对比

运行性能测试脚本：

```bash
# 创建测试脚本
cat > test-performance.sh <<'EOF'
#!/bin/bash
echo "性能测试: 原版 vs 智能版"
echo "========================="

# 测试原版下载
echo -n "原版下载时间: "
time (curl -fsSL https://raw.githubusercontent.com/hello 2>/dev/null)

# 测试智能下载
echo -n "智能下载时间: "
time (smart_download --urls "https://raw.githubusercontent.com/hello" --output /tmp/test 2>/dev/null)

# 测试缓存效果
echo -n "缓存读取时间: "
time (smart_download --urls "https://raw.githubusercontent.com/hello" --output /tmp/test2 --cache 2>/dev/null)
EOF

chmod +x test-performance.sh
./test-performance.sh
```

## 🔧 问题排查

### 常见问题1：库导入失败
**症状**：`source: not found` 或 `smart_download: command not found`

**解决**：
```bash
# 检查库文件是否存在
ls -la lib/*.sh

# 检查执行权限
chmod +x lib/*.sh

# 修改source路径为绝对路径
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "$LIB_DIR/download.sh"
```

### 常见问题2：语法错误
**症状**：`syntax error near unexpected token`

**解决**：
```bash
# 检查脚本语法
bash -n lib/download.sh
bash -n install.sh

# 确保使用bash而不是sh
#!/bin/bash  # 不是 #!/bin/sh
```

### 常见问题3：兼容性问题
**症状**：原功能失效或参数不识别

**解决**：
```bash
# 保持原参数处理
# 在智能版本中保留所有原参数
parse_args() {
    # 原参数处理逻辑保持不变
    # 只添加新参数
}
```

## 📞 获取帮助

如果在迁移过程中遇到问题：

1. **查看文档**：`docs/integration-guide.md`
2. **检查示例**：`example-integration.sh`
3. **提交Issue**：https://github.com/slobys/openclash-auto-installer/issues
4. **回滚更改**：使用备份文件恢复

## 🎯 迁移完成检查清单

- [ ] 所有原脚本功能测试通过
- [ ] 智能功能正常工作
- [ ] 错误处理友好有效
- [ ] 缓存系统正常工作
- [ ] 网络诊断工具可用
- [ ] 文档更新完成
- [ ] GitHub Actions 测试通过（如果使用）
- [ ] 用户文档更新

---

**迁移完成！** 🎉

你的项目现在拥有了：
- ✅ 多源备用下载
- ✅ 智能缓存系统  
- ✅ 网络诊断与恢复
- ✅ 专业错误处理
- ✅ 离线模式支持
- ✅ 向后兼容原版