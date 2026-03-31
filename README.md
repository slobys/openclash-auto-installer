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
  - 安装或更新 PassWall
  - 自动安装 LuCI 包与中文语言包
  - 采用轻刷新模式；安装后会清理 LuCI 菜单缓存并重启 `rpcd`，帮助菜单及时显示
  - 若 `luci-app-passwall` 状态存在但 `/usr/share/passwall/utils.sh` 等关键文件缺失，会自动强制重装 LuCI 包
  - 若 `/etc/config/passwall` 缺失或配置过薄，会优先使用 `/usr/share/passwall/0_default_config` 恢复默认配置
  - 若已安装 PassWall2，会提示菜单可能重叠并给出直达路径
  - 若初次显示为英文，刷新页面后中文语言包会自动生效

- `passwall2.sh`
  - 安装或更新 PassWall2
  - 自动安装 LuCI 包与中文语言包
  - 采用轻刷新模式；安装后会清理 LuCI 菜单缓存并重启 `rpcd`，帮助菜单及时显示
  - 若 `luci-app-passwall2` 状态存在但 `/usr/share/passwall2/utils.sh` 等关键文件缺失，会自动强制重装 LuCI 包
  - 若 `/etc/config/passwall2` 缺失或配置过薄，会优先使用 `/usr/share/passwall2/0_default_config` 恢复默认配置
  - 若已安装 PassWall，会提示菜单可能重叠并给出直达路径
  - 若初次显示为英文，刷新页面后中文语言包会自动生效

- `nikki.sh`
  - 安装或更新 Nikki
  - 整体采用轻刷新模式，不重启 `uhttpd`
  - 在 OpenWrt / opkg 环境下，会先检测 `/etc/nikki/ucode/include.uc` 等关键文件
  - 若主包状态存在但文件缺失，会自动强制重装 `nikki` 主包
  - 再调用 Nikki 官方 `install.sh` 完成初始化，并补装中文语言包
  - 安装后会自动修正 `/usr/share/rpcd/ucode/luci.nikki` 执行权限并重启 `rpcd`
  - 确保 `luci.nikki` RPC 对象正常注册
  - 若初次显示为英文，刷新页面后中文语言包会自动生效

### 卸载与菜单

- `full-uninstall.sh`
  - 卸载 PassWall / PassWall2 / Nikki / OpenClash
  - 执行完整清理，重置安装环境
  - 共享核心仍被其他插件依赖时会自动跳过并提示
  - 卸载后会自动清理 LuCI 菜单缓存并重启 `rpcd`
  - 不重启 `uhttpd`，尽量避免中断当前 LuCI 会话

- `menu.sh`
  - 菜单式管理入口

- `check-updates.sh`
  - 独立的更新检测脚本
  - 检查 OpenClash / PassWall / PassWall2 / Nikki 是否有新版本
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
--openclash                安装 / 更新 OpenClash
--openclash-check-update   检查 OpenClash 是否有新版本
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
