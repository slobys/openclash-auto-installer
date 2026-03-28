# OpenClash Auto Installer

![Release](https://img.shields.io/github/v/release/slobys/openclash-auto-installer?style=flat-square)
![License](https://img.shields.io/github/license/slobys/openclash-auto-installer?style=flat-square)
![Workflow](https://img.shields.io/github/actions/workflow/status/slobys/openclash-auto-installer/shell-check.yml?branch=main&style=flat-square)
![Stars](https://img.shields.io/github/stars/slobys/openclash-auto-installer?style=flat-square)

一个面向 **OpenWrt / iStoreOS / ImmortalWrt** 的 **OpenClash 一键安装 / 更新脚本项目**。

这个仓库不只是放一段临时命令，而是尽量整理成一个适合：

- 博客教程引用
- GitHub 公开展示
- 路由器环境快速部署
- 后续长期维护

的脚本型项目。

---

## 功能概览

- 一键安装 OpenClash
- 一键更新 OpenClash
- 一键卸载 OpenClash
- 一键修复 OpenClash 基础运行环境
- 菜单式管理入口
- 自动识别 `opkg` / `apk`
- 自动识别 `fw4/nft` 或 `iptables`
- 自动获取 OpenClash 最新发布版本
- 自动匹配并安装 Meta 内核
- x86_64 自动识别 v1 / v2 / v3 / v4 指令级别
- 支持插件-only / 内核-only 模式
- 支持 GitHub Actions 自动检查 shell 脚本语法

---

## 仓库结构

```text
.
├─ .github/workflows/shell-check.yml
├─ .github/ISSUE_TEMPLATE/
├─ README.md
├─ CHANGELOG.md
├─ LICENSE
├─ install.sh
├─ update.sh
├─ uninstall.sh
├─ repair.sh
├─ menu.sh
└─ .gitignore
```

---

## 一键命令

### 安装 / 更新 OpenClash

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh
```

### 单独更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/update.sh | sh
```

### 卸载 OpenClash

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/uninstall.sh | sh
```

### 修复 OpenClash 基础环境

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/repair.sh | sh
```

### 菜单式管理

推荐直接执行：

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/menu.sh)"
```

如果你的环境支持 `/dev/tty` 交互，下面这种方式通常也可以：

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/menu.sh | sh
```

---

## 高级用法

### 只安装 / 更新插件，不安装内核

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh -s -- --plugin-only
```

### 只安装 Meta 内核

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh -s -- --core-only
```

### 跳过服务重启

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh -s -- --skip-restart
```

### 跳过软件源更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh -s -- --skip-opkg-update
```

---

## 脚本说明

### install.sh

负责安装或更新 OpenClash 插件，并自动尝试下载和安装匹配的 Meta 内核。

### update.sh

适合已安装用户快速升级，默认复用 `install.sh` 并跳过索引刷新。

### uninstall.sh

卸载 OpenClash 插件与 Meta 内核，但默认不主动删除 `/etc/openclash` 配置目录。

### repair.sh

执行基础修复动作，包括目录检查、权限修复、服务重启和状态输出。

### menu.sh

提供菜单式交互入口，适合不想记命令的用户。

---

## 参数说明

```text
--plugin-only       只安装/更新 OpenClash 插件，不安装 Meta 内核
--core-only         只下载并安装 Meta 内核，不安装/更新插件
--skip-restart      完成后不尝试重启 openclash / uhttpd
--skip-opkg-update  跳过软件源更新
-h, --help          显示帮助
```

---

## 兼容性说明

理论适用于：

- OpenWrt
- iStoreOS
- ImmortalWrt
- 其它兼容 `opkg` / `apk` 的类 OpenWrt 系统

注意事项：

- 依赖 GitHub API 与 OpenClash 核心下载地址可访问
- 部分精简固件的软件包名称可能和标准源不同，需要按环境自行微调
- 如果某些依赖包在当前源中不存在，脚本后续会继续朝“更柔和提示”方向增强
- 卸载脚本默认只移除 OpenClash 插件与 Meta 内核，不主动删除 `/etc/openclash` 配置目录，避免误删订阅和配置

---

## 博客引用推荐命令

### 一键安装 / 更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh
```

### 一键修复

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/repair.sh | sh
```

### 一键卸载

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/uninstall.sh | sh
```

### 菜单式管理

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/menu.sh)"
```

仓库里还额外提供了：

- `.github/workflows/shell-check.yml`：自动检查脚本语法与 ShellCheck
- `.github/ISSUE_TEMPLATE/`：用于规范 bug 反馈和功能建议

---

## 为什么这个版本更适合公开分享

相比临时拼接版，这个仓库版本做了这些增强：

- 结构更清晰，适合 GitHub 首页展示
- 安装、更新、卸载、修复、菜单入口职责拆分
- 安装脚本支持参数模式
- 日志输出更清楚，便于排障
- 自动识别当前已安装版本和最新发布标签
- 出错时更容易定位问题
- 补充许可证，更适合公开发布
- 增加 GitHub Actions 自动检查，降低后续维护出错率
- 增加 issue 模板，后续协作更方便
- 增加 Release 版本，项目形态更完整

---

## 致谢

- OpenClash: <https://github.com/vernesong/OpenClash>
- 博客思路来源：<https://naiyous.com/10947.html>
