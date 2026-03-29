# OpenClash Auto Installer

![Release](https://img.shields.io/github/v/release/slobys/openclash-auto-installer?style=flat-square)
![License](https://img.shields.io/github/license/slobys/openclash-auto-installer?style=flat-square)
![Workflow](https://img.shields.io/github/actions/workflow/status/slobys/openclash-auto-installer/shell-check.yml?branch=main&style=flat-square)

适用于 **OpenWrt / iStoreOS / ImmortalWrt** 的代理插件安装、更新、卸载与修复脚本集合。

当前已集成：

- OpenClash
- PassWall
- PassWall2
- Nikki

---

## 功能

- 安装或更新 OpenClash
- 卸载 PassWall
- 卸载 PassWall2
- 卸载 Nikki
- 卸载 OpenClash
- 修复 OpenClash 基础运行环境
- 菜单式管理入口
- 安装或更新 PassWall
- 安装或更新 PassWall2
- 安装或更新 Nikki
- 自动识别 OpenClash 的 `Meta / Smart Meta` 内核通道
- 自动识别 `opkg` / `apk`
- 自动识别 `fw4/nft` 或 `iptables`

---

## 文件说明

- `install.sh`：安装或更新 OpenClash，并尝试安装匹配的 Meta/Smart 内核；完成后输出实际插件版本与内核版本
- `update.sh`：快速更新 OpenClash 入口
- `full-uninstall.sh`：卸载 PassWall / PassWall2 / Nikki / OpenClash（执行完整清理，重置安装环境）
- `repair.sh`：执行 OpenClash 基础修复流程
- `passwall.sh`：安装或更新 PassWall
- `passwall2.sh`：安装或更新 PassWall2
- `nikki.sh`：安装或更新 Nikki
- `menu.sh`：菜单式管理入口

---

## 使用命令

### OpenClash 安装 / 更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh
```

### PassWall 安装 / 更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/passwall.sh | sh
```

### PassWall2 安装 / 更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/passwall2.sh | sh
```

### Nikki 安装 / 更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/nikki.sh | sh
```

### 菜单模式

推荐：

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/menu.sh)"
```

---

## OpenClash 参数

```text
--plugin-only       只安装/更新 OpenClash 插件，不安装 Meta 内核
--core-only         只下载并安装 Meta 内核，不安装/更新插件
--meta-core         强制使用普通 Meta 内核
--smart-core        强制使用 Smart Meta 内核
--skip-restart      完成后不尝试重启 openclash / uhttpd
--skip-opkg-update  跳过软件源更新
-h, --help          显示帮助
```

---

## menu.sh 参数

```text
--openclash                安装 / 更新 OpenClash
--openclash-plugin-only    只更新 OpenClash 插件
--openclash-core-only      只安装 OpenClash 核心（自动识别 Meta / Smart）
--openclash-meta-core      只安装 OpenClash 普通 Meta 内核
--openclash-smart-core     只安装 OpenClash Smart Meta 内核
--passwall                 安装 / 更新 PassWall
--passwall2                安装 / 更新 PassWall2
--nikki                    安装 / 更新 Nikki
--full-uninstall-passwall  卸载 PassWall
--full-uninstall-passwall2 卸载 PassWall2
--full-uninstall-nikki     卸载 Nikki
--full-uninstall-openclash 卸载 OpenClash
-h, --help                 显示帮助
```

---

## 兼容性与说明

支持范围：

- OpenWrt
- iStoreOS
- ImmortalWrt
- 其它兼容 `opkg` / `apk` 的类 OpenWrt 系统

说明：

- OpenClash 默认会自动判断使用普通 Meta 还是 Smart Meta 内核，也可通过参数强制指定
- 遇到 `opkg.lock` 时，脚本会提示并自动重试一次；如你刚刷新过软件源，也可使用 `--skip-opkg-update`
- 部分精简固件的软件包名称或软件源配置可能和标准环境不同，必要时需自行微调
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
├─ passwall.sh
├─ passwall2.sh
├─ nikki.sh
├─ menu.sh
└─ .gitignore
```

---

## 致谢

- OpenClash: <https://github.com/vernesong/OpenClash>
- PassWall: <https://github.com/Openwrt-Passwall/openwrt-passwall>
- PassWall2: <https://github.com/Openwrt-Passwall/openwrt-passwall2>
- Nikki: <https://github.com/nikkinikki-org/OpenWrt-nikki>
