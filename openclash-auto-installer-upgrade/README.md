# OpenClash Auto-Installer 智能网络层增强版

基于原 `openclash-auto-installer` 项目的全面升级，集成**智能网络层**，解决网络不稳定、下载失败、错误处理不完善等问题。

## 🚀 核心特性

### 📥 **智能下载引擎**
- **多源备用**：每个资源3-4个备用源 (GitHub → jsDelivr → ghproxy → 自定义)
- **自动重试**：失败后自动切换源和下载工具 (curl → wget → aria2c)
- **断点续传**：大文件支持断点续传
- **哈希校验**：SHA256/MD5 校验确保文件完整性

### 💾 **智能缓存系统**
- **自动缓存**：下载文件自动缓存，支持离线安装
- **缓存验证**：完整性检查，防止损坏缓存
- **缓存管理**：查看、清理、导入导出工具
- **空间管理**：自动清理旧缓存，防止磁盘占满

### 🌐 **网络诊断与恢复**
- **全面诊断**：连通性、服务可达性、镜像延迟测试
- **自动修复**：DNS、代理、时间等常见问题自动修复
- **镜像选择**：自动检测最快镜像源
- **离线模式**：网络异常时自动切换离线模式

### 🚨 **专业错误处理**
- **友好错误**：不再是"下载失败"，而是"下载失败，建议：1. xxx 2. xxx"
- **自动恢复**：常见错误自动尝试恢复
- **错误报告**：一键生成详细错误报告
- **日志系统**：结构化日志，便于排查

## 📁 项目结构

```
openclash-auto-installer/
├── lib/                          # 智能网络层核心库
│   ├── download.sh              # 核心下载引擎
│   ├── network.sh               # 网络诊断工具
│   ├── cache.sh                 # 缓存管理系统
│   └── error.sh                 # 错误处理框架
├── scripts/                     # 增强版业务脚本
│   ├── install.sh              # OpenClash 安装 (智能版)
│   ├── network-diagnose.sh     # 网络诊断工具
│   ├── cache-manager.sh        # 缓存管理工具
│   └── (其他插件脚本)          # passwall.sh 等升级版
├── config/                      # 配置文件
│   └── mirrors.conf            # 镜像源配置
├── tools/                       # 辅助工具
│   ├── migrate.sh              # 脚本迁移工具 (计划中)
│   └── batch-update.sh         # 批量更新工具
├── docs/                        # 文档
│   ├── integration-guide.md    # 集成指南
│   └── troubleshooting.md      # 故障排查
└── example-integration.sh      # 集成示例
```

## 🎯 快速开始

### 1. 直接使用增强版脚本

```bash
# 使用智能安装脚本 (自动处理网络问题)
sh -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/slobys/openclash-auto-installer@smart/scripts/install.sh)"

# 或指定镜像源
sh -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/slobys/openclash-auto-installer@smart/scripts/install.sh)" --mirror jsdelivr

# 离线安装 (使用缓存)
sh -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/slobys/openclash-auto-installer@smart/scripts/install.sh)" --offline
```

### 2. 网络诊断

```bash
# 运行网络诊断
curl -fsSL https://cdn.jsdelivr.net/gh/slobys/openclash-auto-installer@smart/scripts/network-diagnose.sh | sh

# 或下载后运行
curl -fsSL https://cdn.jsdelivr.net/gh/slobys/openclash-auto-installer@smart/scripts/network-diagnose.sh -o /tmp/network-diagnose.sh
sh /tmp/network-diagnose.sh --full
```

### 3. 缓存管理

```bash
# 查看缓存状态
curl -fsSL https://cdn.jsdelivr.net/gh/slobys/openclash-auto-installer@smart/scripts/cache-manager.sh | sh -s stats

# 清理7天前缓存
curl -fsSL https://cdn.jsdelivr.net/gh/slobys/openclash-auto-installer@smart/scripts/cache-manager.sh | sh -s clean "*" 7
```

## 🔧 集成到现有项目

### 方法1：完整替换 (推荐)
用增强版脚本完全替换原脚本：

```bash
# 备份原脚本
cp install.sh install.sh.backup

# 使用增强版
cp scripts/install.sh install.sh
chmod +x install.sh
```

### 方法2：逐步集成
在现有脚本中集成智能网络层：

```bash
# 1. 导入库
LIB_DIR="/path/to/lib"
source "$LIB_DIR/error.sh"
source "$LIB_DIR/download.sh"

# 2. 设置错误处理
set_error_trap "$(basename "$0")"
setup_error_logging

# 3. 替换下载函数
# 原代码: curl -fsSL "$URL" -o "$OUTPUT"
# 新代码:
smart_download --urls "$URL" --output "$OUTPUT" --cache

# 4. 替换公钥下载
# 原代码: wget -qO passwall.pub "$KEY_URL"
# 新代码:
download_pubkey "passwall" "/tmp/passwall.pub"
```

### 方法3：使用迁移工具 (计划中)
```bash
# 自动迁移脚本
./tools/migrate.sh old_passwall.sh new_passwall.sh
```

## ⚙️ 配置说明

### 镜像源配置 (`config/mirrors.conf`)
```ini
# 服务名=镜像1 镜像2 镜像3
github.raw=https://raw.githubusercontent.com https://cdn.jsdelivr.net/gh https://ghproxy.com/https://raw.githubusercontent.com
openclash.api=https://api.github.com/repos/vernesong/OpenClash/releases/latest
passwall.key=https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall/main/passwall.pub
```

### 环境变量
```bash
# 网络相关
export USE_MIRROR="jsdelivr"      # 指定镜像源
export OFFLINE_MODE=1             # 离线模式
export ENABLE_CACHE=1             # 启用缓存
export CACHE_DIR="/tmp/my-cache"  # 自定义缓存目录

# 调试相关
export DEBUG=1                    # 调试模式
export LOG_LEVEL="DEBUG"          # 日志级别
export FORCE_YES=1                # 跳过确认

# 代理设置
export http_proxy="http://proxy:port"
export https_proxy="http://proxy:port"
```

## 🛠️ 工具使用

### 网络诊断工具
```bash
# 完整诊断
./scripts/network-diagnose.sh --full

# 快速诊断
./scripts/network-diagnose.sh --quick

# 尝试自动修复
./scripts/network-diagnose.sh --fix

# 测试特定服务
./scripts/network-diagnose.sh --test github
./scripts/network-diagnose.sh --test raw
./scripts/network-diagnose.sh --test jsdelivr

# 生成报告
./scripts/network-diagnose.sh --report /tmp/network-report.txt
```

### 缓存管理工具
```bash
# 交互式菜单
./scripts/cache-manager.sh menu

# 命令行操作
./scripts/cache-manager.sh stats                    # 统计
./scripts/cache-manager.sh list detailed            # 详细列表
./scripts/cache-manager.sh find "passwall"          # 查找
./scripts/cache-manager.sh clean "*" 7              # 清理7天前
./scripts/cache-manager.sh export ./my-cache        # 导出
./scripts/cache-manager.sh import ./my-cache        # 导入
./scripts/cache-manager.sh verify                   # 验证
```

## 📊 性能对比

| 功能 | 原版 | 智能网络层版 | 改进 |
|------|------|--------------|------|
| 下载失败处理 | 直接报错 | 自动重试3个源+2种工具 | ✅ |
| 网络异常 | 脚本卡死 | 自动诊断+建议 | ✅ |
| 离线安装 | 不支持 | 完整支持 | ✅ |
| 错误信息 | "下载失败" | "下载失败，建议：1. xxx 2. xxx" | ✅ |
| 缓存管理 | 无 | 完整缓存系统 | ✅ |
| 镜像加速 | 硬编码单一源 | 多源自动选择 | ✅ |
| 进度显示 | 无 | 彩色进度+动画 | ✅ |

## 🔍 故障排查

### 常见问题

#### Q1: 下载仍然失败
```bash
# 启用调试模式
DEBUG=1 sh install.sh

# 查看详细日志
tail -f /tmp/openclash-smart-install.log

# 运行网络诊断
sh network-diagnose.sh --full
```

#### Q2: 缓存不工作
```bash
# 检查缓存目录权限
ls -ld /tmp/openclash-smart-cache

# 手动设置缓存目录
export CACHE_DIR="/tmp/my-cache"
mkdir -p "$CACHE_DIR"

# 查看缓存状态
sh cache-manager.sh stats
```

#### Q3: 脚本执行慢
```bash
# 禁用网络测试
sh install.sh --skip-env-check

# 使用指定镜像
sh install.sh --mirror jsdelivr

# 预先下载依赖
sh network-diagnose.sh --test github
```

### 错误代码参考

| 代码 | 含义 | 解决方案 |
|------|------|----------|
| 1 | 一般错误 | 检查脚本语法、权限 |
| 4 | 网络错误 | 运行网络诊断，使用离线模式 |
| 5 | 权限错误 | 使用root/sudo执行 |
| 22 | HTTP错误 | URL失效，使用镜像源 |
| 28 | 超时错误 | 增加超时时间，检查网络 |
| 255 | 命令未找到 | 安装缺少的命令 |

## 🤝 贡献指南

### 开发流程
1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/network-layer`)
3. 提交更改 (`git commit -m 'Add network layer'`)
4. 推送到分支 (`git push origin feature/network-layer`)
5. 创建 Pull Request

### 测试要求
- [ ] 网络正常环境测试
- [ ] 网络异常环境测试
- [ ] 离线模式测试
- [ ] 缓存功能测试
- [ ] 错误处理测试

### 代码规范
- 使用 `shellcheck` 检查语法
- 遵循现有代码风格
- 添加详细注释
- 更新相关文档

## 📄 许可证

本项目基于原 `openclash-auto-installer` 的 MIT 许可证。

## 🙏 致谢

- 原项目作者: [slobys](https://github.com/slobys)
- OpenClash 项目: [vernesong](https://github.com/vernesong/OpenClash)
- 所有贡献者和用户

## 📞 支持

- GitHub Issues: [报告问题](https://github.com/slobys/openclash-auto-installer/issues)
- 文档: [查看文档](https://github.com/slobys/openclash-auto-installer/tree/smart/docs)
- 社区: [Discussions](https://github.com/slobys/openclash-auto-installer/discussions)

---

**智能网络层版** · 让安装更稳定，让网络不再是问题 🚀