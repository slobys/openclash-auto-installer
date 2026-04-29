# OpenClash Auto Installer

![Release](https://img.shields.io/github/v/release/slobys/openclash-auto-installer?style=flat-square)
![License](https://img.shields.io/github/license/slobys/openclash-auto-installer?style=flat-square)
![Workflow](https://img.shields.io/github/actions/workflow/status/slobys/openclash-auto-installer/shell-check.yml?branch=main&style=flat-square)

适用于 **OpenWrt / iStoreOS / ImmortalWrt** 的代理插件安装、更新、卸载与修复脚本集合。  
以 **OpenClash** 为核心入口，统一提供 **PassWall / PassWall2 / Nikki / SmartDNS** 的常用安装、更新、卸载与检查脚本。

> **推荐环境：OpenWrt / iStoreOS / ImmortalWrt 24.x 及以上**
>
> 近期实测表明，**24.x 及以上版本整体更稳定**；低于 24 的版本、非标准发行版、以及版本号映射异常的固件更容易出现：
> - 软件源目录推导错误
> - 依赖不兼容
> - feed / 包索引不可用
> - 安装后行为不稳定
>
> 如果你的系统低于 OpenWrt 24，建议优先使用手动方式安装，或自行确认该固件的软件源与依赖兼容性。

当前已集成：

- OpenClash
- PassWall
- PassWall2
- Nikki
- SmartDNS

---

## 适合谁 / 不适合谁

### 适合
- 想快速安装或更新 OpenClash 的 OpenWrt / iStoreOS / ImmortalWrt 用户
- 希望集中管理 PassWall / PassWall2 / Nikki / SmartDNS / OpenClash 的用户
- 想用尽量接近官方安装逻辑、同时减少手工操作的人

### 不适合
- 需要兼容大量非标准固件、魔改软件源、特殊架构环境的场景
- 希望脚本自动处理所有第三方源异常、依赖冲突、旧版系统兼容问题的场景
- 不愿意自行确认高风险环境（低版本 / apk 初期适配 / 特殊防火墙栈）的用户

---

## 推荐使用方式

如果你只是想：

- **安装 / 更新 OpenClash** → 用 `install.sh`
- **交互式统一管理多个插件** → 用 `menu.sh`
- **只检查是否有新版本** → 用 `check-updates.sh`
- **修复 OpenClash 基础运行环境** → 用 `repair.sh`
- **安全卸载插件** → 用 `uninstall.sh`

---

## 支持范围说明

### 推荐
- OpenWrt 24.10.x
- iStoreOS 24.10.x
- ImmortalWrt 24.10.x

### 可兼容但建议先验证
- 23.05.x
- 22.03.x

### 高风险环境
- 版本号、架构名、软件源路径与官方规范差异较大的第三方固件
- OpenWrt 25.12+ / `apk` 环境（部分插件仍在适配中）
- 使用 `iptables` 而非 `firewall4/nftables` 的环境（Nikki 不支持）

### 当前原则
- 安装优先走接近官方 / 手动 IPK 的方式
- 卸载默认走安全卸载，只移除主包和对应配置
- 稳定优先，不做激进清理

---

## 支持矩阵

| 功能 | OpenWrt / iStoreOS / ImmortalWrt 24.x+ | 23.05 / 22.03 及更早 | OpenWrt 25.12+ / `apk` |
|------|----------------------------------------|----------------------|-------------------------|
| OpenClash 安装 / 更新 | ✅ 推荐 | ⚠️ 谨慎使用 | ⚠️ 初步适配 |
| PassWall 安装 / 更新 | ✅ 推荐 | ⚠️ 谨慎使用 | ❌ 暂未适配 |
| PassWall2 安装 / 更新 | ✅ 推荐 | ⚠️ 谨慎使用 | ❌ 暂未适配 |
| Nikki 安装 / 更新 | ✅ 推荐 | ⚠️ 谨慎使用 | ⚠️ 受 `firewall4` / nftables 限制 |
| SmartDNS 安装 / 更新 | ✅ 推荐 | ⚠️ 谨慎使用 | ⚠️ 初步适配 |
| 安全卸载 | ✅ 推荐 | ⚠️ 谨慎使用 | ⚠️ 取决于当前插件支持情况 |
| 更新检测 | ✅ 推荐 | ⚠️ 谨慎使用 | ⚠️ 部分场景仍需继续验证 |

---

## 功能

- 安装或更新 OpenClash
- 安装或更新 PassWall
- 安装或更新 PassWall2
- 安装或更新 Nikki
- 安装或更新 SmartDNS
- 卸载 PassWall
- 卸载 PassWall2
- 卸载 Nikki
- 卸载 SmartDNS
- 卸载 OpenClash
- 修复 OpenClash 基础运行环境
- 菜单式管理入口
- 检查 OpenClash / PassWall / PassWall2 / Nikki / SmartDNS 是否有新版本
- 自动识别 OpenClash 的 `Meta / Smart Meta` 内核通道
- 自动识别 `opkg` / `apk`
- 自动识别 `fw4/nft` 或 `iptables`

---

## 文件说明

### OpenClash 相关

- `install.sh`
  - 安装或更新 OpenClash
  - 自动尝试安装匹配的 Meta / Smart 内核
  - 已兼容 `openclash.config.smart_enable` 等字段，提升 Smart Meta 自动识别准确性
  - 安装后会清理 LuCI 菜单缓存并重启 `rpcd`，帮助菜单及时显示
  - 完成后输出实际插件版本与内核版本

- `update.sh`
  - 快速更新 OpenClash 入口
  - 支持仅检查是否有新版本，不自动更新

- `repair.sh`
  - 执行 OpenClash 基础修复流程

### 代理插件安装

- `passwall.sh`
  - 按接近官方 IPK 的方式安装或更新 PassWall
  - 自动安装 LuCI 主包与中文语言包
  - 会根据系统版本优先映射到兼容的 22.03 / 23.05 / 24.10 构建目录
  - 默认不改写现有 `/etc/config/passwall`
  - 安装后会清理 LuCI 菜单缓存并重启 `rpcd`
  - 若当前固件为非标准版本号或依赖不兼容，会直接给出更明确的排障提示

- `passwall2.sh`
  - 按接近官方 IPK 的方式安装或更新 PassWall2
  - 自动安装 LuCI 主包与中文语言包
  - 会根据系统版本优先映射到兼容的 22.03 / 23.05 / 24.10 构建目录
  - 默认不改写现有 `/etc/config/passwall2`
  - 安装后会清理 LuCI 菜单缓存并重启 `rpcd`
  - 若当前固件为非标准版本号或依赖不兼容，会直接给出更明确的排障提示

- `nikki.sh`
  - 按 Nikki 官方 `feed.sh` / `install.sh` 流程安装或更新 Nikki
  - 整体采用轻刷新模式，不重启 `uhttpd`
  - 保留防火墙栈检测与官方安装流程
  - 若检测到 `iptables` 环境，会明确提示 Nikki 仅支持 `firewall4/nftables`
  - 仅补装中文语言包，不主动做额外配置修复
  - 默认不改写现有 Nikki 配置
  - 若初次显示为英文，刷新页面后中文语言包会自动生效

- `smartdns.sh`
  - 从 SmartDNS 官方 GitHub Release 下载匹配架构的 OpenWrt 包
  - 自动安装 / 更新 `smartdns` 与 `luci-app-smartdns`
  - 支持 `opkg` / `apk`，并自动识别 x86_64 / x86 / aarch64 / arm / mips / mipsel
  - 默认只启用并重启 SmartDNS 服务，不主动改写 `/etc/config/smartdns`
  - 安装后会清理 LuCI 菜单缓存并重启 `rpcd`

### 卸载与菜单

- `uninstall.sh`
  - 安全卸载 PassWall / PassWall2 / Nikki / SmartDNS / OpenClash
  - 仅移除主包，不碰共享依赖
  - 可按需删除对应配置文件
  - 卸载后会自动清理 LuCI 菜单缓存并重启 `rpcd`
  - 不重启 `uhttpd`，尽量避免中断当前 LuCI 会话

- `menu.sh`
  - 菜单式管理入口

- `check-updates.sh`
  - 独立的更新检测脚本
  - 检查 OpenClash / PassWall / PassWall2 / Nikki / SmartDNS 是否有新版本
  - 只检测，不自动更新

---

## 使用命令

### OpenClash 安装 / 更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh
```

### 仅检查 OpenClash 是否有新版本

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh -s -- --check-update
```

或：

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/update.sh | sh -s -- --check
```

### 检查所有插件是否有新版本

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/check-updates.sh | sh
```

也支持单独检查：

```sh
sh check-updates.sh --openclash
sh check-updates.sh --passwall
sh check-updates.sh --passwall2
sh check-updates.sh --nikki
sh check-updates.sh --smartdns
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

### SmartDNS 安装 / 更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/smartdns.sh | sh
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
--check-update      只检查是否有新版本，不执行安装/更新
--meta-core         强制使用普通 Meta 内核
--smart-core        强制使用 Smart Meta 内核
--skip-restart      完成后不尝试重启 openclash / uhttpd
--skip-opkg-update  跳过软件源更新
-h, --help          显示帮助
```

---

## menu.sh 参数

```text
--check-all-updates        检查所有插件是否有新版本
--check-updates            打开“检查插件更新”二级菜单
--check-update-openclash   仅检查 OpenClash
--check-update-passwall    仅检查 PassWall
--check-update-passwall2   仅检查 PassWall2
--check-update-nikki       仅检查 Nikki
--check-update-smartdns    仅检查 SmartDNS
--openclash                安装 / 更新 OpenClash
--openclash-check-update   检查 OpenClash 是否有新版本
--openclash-plugin-only    只更新 OpenClash 插件
--openclash-core-only      只安装 OpenClash 核心（自动识别 Meta / Smart）
--openclash-meta-core      只安装 OpenClash 普通 Meta 内核
--openclash-smart-core     只安装 OpenClash Smart Meta 内核
--passwall                 安装 / 更新 PassWall
--passwall2                安装 / 更新 PassWall2
--nikki                    安装 / 更新 Nikki
--smartdns                 安装 / 更新 SmartDNS
--uninstall-passwall       安全卸载 PassWall（仅主包 + 删除配置）
--uninstall-passwall2      安全卸载 PassWall2（仅主包 + 删除配置）
--uninstall-nikki          安全卸载 Nikki（仅主包 + 删除配置）
--uninstall-smartdns       安全卸载 SmartDNS（仅主包 + 删除配置）
--uninstall-openclash      安全卸载 OpenClash（仅主包 + 删除配置）
-h, --help                 显示帮助
```

---

## 已知限制

- `apk` 环境目前仍处于逐步适配阶段，不应视为“所有插件已完全支持”
- PassWall / PassWall2 在 `apk` 环境下暂未适配，检测到相关环境会报错退出
- Nikki 依赖 `firewall4`（nftables），若系统为 `iptables` 会提前报错
- SmartDNS 使用官方 GitHub Release 包安装，暂不自动生成或接管 DNS 配置
- 部分精简固件的软件包名称、软件源配置、架构命名可能与标准环境不同，必要时需自行微调
- 卸载脚本默认不删除 `/etc/openclash` 配置目录，避免误删订阅和已有配置

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
- **OpenWrt 25.12+**：系统已改用 `apk` 包管理器，本脚本集合已增加兼容性检测
  - OpenClash 安装脚本已初步适配 `apk`，但依赖包名可能仍需调整
  - PassWall / PassWall2 脚本暂未适配 `apk`，若检测到 `apk` 会报错退出
  - Nikki 需要 `firewall4`（nftables）支持，若系统为 `iptables` 会提前报错
  - SmartDNS 会尝试使用官方 `.apk` Release 包安装，仍建议先在目标固件验证
  - 若你使用 OpenWrt 25.12+ 遇到问题，请参考项目 issue 或使用 25.11 及更早版本

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
├─ smartdns.sh
├─ menu.sh
├─ check-updates.sh
├─ auto-download-pro.sh
├─ test-auto-download.sh
└─ .gitignore
```

---

## 致谢

- OpenClash: <https://github.com/vernesong/OpenClash>
- PassWall: <https://github.com/Openwrt-Passwall/openwrt-passwall>
- PassWall2: <https://github.com/Openwrt-Passwall/openwrt-passwall2>
- Nikki: <https://github.com/nikkinikki-org/OpenWrt-nikki>
- SmartDNS: <https://github.com/pymumu/smartdns>
