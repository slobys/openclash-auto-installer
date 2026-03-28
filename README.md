# OpenClash Auto Installer

![Release](https://img.shields.io/github/v/release/slobys/openclash-auto-installer?style=flat-square)
![License](https://img.shields.io/github/license/slobys/openclash-auto-installer?style=flat-square)
![Workflow](https://img.shields.io/github/actions/workflow/status/slobys/openclash-auto-installer/shell-check.yml?branch=main&style=flat-square)

适用于 **OpenWrt / iStoreOS / ImmortalWrt** 的 OpenClash 安装、更新、卸载与修复脚本。

---

## 功能

- 安装或更新 OpenClash
- 卸载 OpenClash
- 修复 OpenClash 基础运行环境
- 菜单式管理入口
- 自动识别 `opkg` / `apk`
- 自动识别 `fw4/nft` 或 `iptables`
- 自动获取 OpenClash 最新发布版本
- 自动匹配并安装 Meta 内核
- x86_64 自动识别 v1 / v2 / v3 / v4 指令级别

---

## 文件说明

- `install.sh`：安装或更新 OpenClash，并尝试安装匹配的 Meta 内核
- `update.sh`：快速更新入口
- `uninstall.sh`：卸载 OpenClash 插件与 Meta 内核
- `repair.sh`：执行基础修复流程
- `menu.sh`：菜单式管理入口

---

## 使用命令

### 安装 / 更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh
```

### 更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/update.sh | sh
```

### 卸载

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/uninstall.sh | sh
```

### 修复

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/repair.sh | sh
```

### 菜单模式

推荐：

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/menu.sh)"
```

也可使用：

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/menu.sh | sh
```

---

## install.sh 参数

```text
--plugin-only       只安装/更新 OpenClash 插件，不安装 Meta 内核
--core-only         只下载并安装 Meta 内核，不安装/更新插件
--skip-restart      完成后不尝试重启 openclash / uhttpd
--skip-opkg-update  跳过软件源更新
-h, --help          显示帮助
```

---

## menu.sh 参数

```text
--install           直接执行安装/更新
--plugin-only       直接执行插件安装/更新
--core-only         直接执行 Meta 内核安装
--uninstall         直接执行卸载
-h, --help          显示帮助
```

---

## 兼容性与说明

支持范围：

- OpenWrt
- iStoreOS
- ImmortalWrt
- 其它兼容 `opkg` / `apk` 的类 OpenWrt 系统

说明：

- 依赖 GitHub API 与 OpenClash 核心下载地址可访问
- 部分精简固件的软件包名称可能和标准源不同，必要时需自行微调
- 卸载脚本默认不删除 `/etc/openclash` 配置目录，避免误删订阅和配置

---

## 项目文件

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

## 致谢

- OpenClash: <https://github.com/vernesong/OpenClash>
