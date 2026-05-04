# OpenClash Auto Installer

![Release](https://img.shields.io/github/v/release/slobys/openclash-auto-installer?style=flat-square)
![License](https://img.shields.io/github/license/slobys/openclash-auto-installer?style=flat-square)
![Workflow](https://img.shields.io/github/actions/workflow/status/slobys/openclash-auto-installer/shell-check.yml?branch=main&style=flat-square)

适用于 **OpenWrt / iStoreOS / ImmortalWrt** 的代理插件安装、更新、卸载与检查脚本集合。

已集成：

- OpenClash
- PassWall
- PassWall2
- Nikki
- SmartDNS
- MosDNS

---

## 一键使用

推荐直接使用菜单模式，安装、更新、检查版本和卸载都在菜单里：

```sh
sh -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/slobys/openclash-auto-installer@main/menu.sh)"
```

菜单结构：

```text
1. 检查插件更新
2. 安装插件
3. 卸载插件
0. 退出
```

---

## 支持范围

推荐使用：

- OpenWrt 24.10.x
- iStoreOS 24.10.x
- ImmortalWrt 24.10.x

可尝试但建议先验证：

- OpenWrt 23.05.x / 22.03.x
- 第三方固件或精简固件
- OpenWrt 25.12+ / `apk` 环境

---

## 功能说明

| 插件 | 支持内容 | 说明 |
|------|----------|------|
| OpenClash | 安装 / 更新 / 核心安装 / 卸载 / 更新检测 | 自动识别 Meta / Smart Meta 内核 |
| PassWall | 安装 / 更新 / 卸载 / 更新检测 | 当前主要面向 `opkg` 环境 |
| PassWall2 | 安装 / 更新 / 卸载 / 更新检测 | 当前主要面向 `opkg` 环境 |
| Nikki | 安装 / 更新 / 卸载 / 更新检测 | 需要 `firewall4/nftables` |
| SmartDNS | 安装 / 更新 / 卸载 / 更新检测 | 使用官方 GitHub Release 包 |
| MosDNS | 安装 / 更新 / 卸载 / 更新检测 | 使用 `sbwml/luci-app-mosdns` GitHub Release 包 |

---

## 重要说明

- 推荐 OpenWrt / iStoreOS / ImmortalWrt 24.x 及以上，整体更稳定。
- 低版本、魔改固件、精简固件可能遇到依赖或软件源不兼容。
- OpenWrt 25.12+ 的 `apk` 环境仍属于初步适配。
- PassWall / PassWall2 暂不适配 `apk` 环境。
- Nikki 不支持 `iptables` 防火墙栈。
- SmartDNS 只安装程序和 LuCI 界面，不自动接管或改写 DNS 配置。
- MosDNS 只安装程序、LuCI 界面和上游 Release 包内的基础数据包，不自动接管或改写 DNS 配置。
- 卸载默认走安全卸载，只移除主包和对应配置，不做激进清理。

---

## 文件说明

| 文件 | 作用 |
|------|------|
| `menu.sh` | 统一菜单入口 |
| `install.sh` | OpenClash 安装 / 更新 |
| `update.sh` | OpenClash 快速更新入口 |
| `repair.sh` | OpenClash 基础修复 |
| `passwall.sh` | PassWall 安装 / 更新 |
| `passwall2.sh` | PassWall2 安装 / 更新 |
| `nikki.sh` | Nikki 安装 / 更新 |
| `smartdns.sh` | SmartDNS 安装 / 更新 |
| `mosdns.sh` | MosDNS 安装 / 更新 |
| `check-updates.sh` | 检查插件更新 |
| `uninstall.sh` | 安全卸载插件 |

---

## 致谢

- OpenClash: <https://github.com/vernesong/OpenClash>
- PassWall: <https://github.com/Openwrt-Passwall/openwrt-passwall>
- PassWall2: <https://github.com/Openwrt-Passwall/openwrt-passwall2>
- Nikki: <https://github.com/nikkinikki-org/OpenWrt-nikki>
- SmartDNS: <https://github.com/pymumu/smartdns>
- MosDNS LuCI: <https://github.com/sbwml/luci-app-mosdns>
