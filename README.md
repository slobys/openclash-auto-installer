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
- daed

---

## 一键使用

推荐直接使用菜单模式，安装、更新、检查版本和卸载都在菜单里：

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/menu.sh)"
```

固定稳定版可使用 Release 标签，例如：

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/v1.2.4/menu.sh)"
```

如果 GitHub raw 访问慢，可用 jsDelivr：

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

- OpenWrt 25.12+ / `apk` 环境
- OpenWrt 23.05.x / 22.03.x
- 第三方固件或精简固件

---

## 功能说明

| 插件 | 支持内容 | 说明 |
|------|----------|------|
| OpenClash | 安装 / 更新 / 核心安装 / 卸载 / 更新检测 | 自动识别 Meta / Smart Meta 内核 |
| PassWall | 安装 / 更新 / 卸载 / 更新检测 | 支持 `opkg`；OpenWrt 25.12+ 下尝试安装上游 `.apk` 构建 |
| PassWall2 | 安装 / 更新 / 卸载 / 更新检测 | 支持 `opkg`；OpenWrt 25.12+ 下尝试安装上游 `.apk` 构建 |
| Nikki | 安装 / 更新 / 卸载 / 更新检测 | 需要 `firewall4/nftables` |
| SmartDNS | 安装 / 更新 / 卸载 / 更新检测 | 使用官方 GitHub Release 包 |
| MosDNS | 安装 / 更新 / 卸载 / 更新检测 | 使用 `sbwml/luci-app-mosdns` GitHub Release 包 |
| daed | 安装 / 更新 / LuCI 管理 / 卸载 / 更新检测 | 使用官方静态二进制，并集成 `luci-app-daed`，面板端口为 `2023` |

---

## OpenWrt 25.12+ / apk 说明

OpenWrt 25.12+ 使用 `apk` 包管理器，本项目已同步适配：

- 安装 / 更新
- 检查更新
- 卸载

PassWall / PassWall2 在 25.12+ 下会尝试安装上游 `.apk` 构建，实际可用性取决于上游是否发布对应架构包。

---

## 重要说明

- 推荐 OpenWrt / iStoreOS / ImmortalWrt 24.x 及以上，整体更稳定。
- 低版本、魔改固件、精简固件可能遇到依赖或软件源不兼容。
- OpenWrt 25.12+ 的 `apk` 环境已做基础适配，但仍可能受上游包影响。
- Nikki 不支持 `iptables` 防火墙栈，需要 `firewall4/nftables`。
- SmartDNS 只安装程序和 LuCI 界面，不自动接管或改写 DNS 配置。
- MosDNS 只安装程序、LuCI 界面和上游 Release 包内的基础数据包，不自动接管或改写 DNS 配置。
- daed 全新安装后，LuCI 中的“启用”选项默认不勾选，请在“服务 → DAED”中手动启用；脚本不会在安装结束时额外停止或禁用服务。启动后可查看日志和打开仪表板，也可直接访问 `http://路由器IP:2023`。
- LuCI DAED 界面使用 `QiuSimons/luci-app-daed` 的 OpenWrt 24.10 `ipk` 或 25.12 `apk`；旧版或特殊固件若界面包不兼容，脚本仍会保留可独立使用的 daed 后端。
- daed 依赖 eBPF/BTF，要求 Linux 5.17+ 且内核开启相关能力；许多裁剪过的 OpenWrt 固件无法运行。
- OpenWrt 25.12.4 的 `apk` 与 LuCI 界面包已适配，但官方原版固件通常没有 daed 所需的完整 BTF/eBPF 能力；脚本会在安装前检查内置 BTF 或与当前内核严格匹配的外置 `vmlinux-btf`，不满足时明确终止。
- daed 安装后约占用 85MB，安装过程还要求 `/tmp` 至少有 130MB 可用空间。
- daed 官方预编译包支持 arm64、MIPS32/64、RISC-V 64 和 x86，不支持 ARMv7 等未发布架构。
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
| `daed.sh` | daed 安装 / 更新 |
| `check-updates.sh` | 检查插件更新 |
| `uninstall.sh` | 安全卸载插件 |
| `auto-download-pro.sh` | 旧入口兼容包装器，已转交给 `passwall.sh` |
| `test-auto-download.sh` | 旧测试入口兼容包装器，已转交给 `passwall.sh` |

---

## 致谢

- OpenClash: <https://github.com/vernesong/OpenClash>
- PassWall: <https://github.com/Openwrt-Passwall/openwrt-passwall>
- PassWall2: <https://github.com/Openwrt-Passwall/openwrt-passwall2>
- Nikki: <https://github.com/nikkinikki-org/OpenWrt-nikki>
- SmartDNS: <https://github.com/pymumu/smartdns>
- MosDNS LuCI: <https://github.com/sbwml/luci-app-mosdns>
- daed: <https://github.com/daeuniverse/daed>
- daed LuCI: <https://github.com/QiuSimons/luci-app-daed>
