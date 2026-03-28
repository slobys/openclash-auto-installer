# OpenClash Auto Installer

一个面向 **OpenWrt / iStoreOS / ImmortalWrt** 的 **OpenClash 一键安装 / 更新脚本项目**。

这个仓库不只是放一段临时命令，而是尽量整理成一个适合：

- 博客教程引用
- GitHub 公开展示
- 路由器环境快速部署
- 后续长期维护

的脚本型项目。

---

## 项目功能

目前已支持：

- 一键安装 OpenClash
- 一键更新 OpenClash
- 自动识别 `opkg` / `apk`
- 自动识别 `fw4/nft` 或 `iptables`
- 自动安装依赖组件
- 自动获取 OpenClash 最新发布版本
- 自动匹配并安装 Meta 内核
- 对 x86_64 自动识别 v1 / v2 / v3 / v4 指令级别
- 可选只装插件 / 只装内核
- 可选跳过服务重启 / 跳过索引更新

---

## 仓库结构

```text
.
├─ README.md
├─ CHANGELOG.md
├─ install.sh
├─ update.sh
├─ uninstall.sh
└─ .gitignore
```

---

## 一键命令

### 安装 / 更新 OpenClash

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/install.sh | sh
```

或：

```sh
wget -qO- https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/install.sh | sh
```

### 单独更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/update.sh | sh
```

### 卸载 OpenClash

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/uninstall.sh | sh
```

---

## 高级用法

### 只安装 / 更新插件，不安装内核

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/install.sh | sh -s -- --plugin-only
```

### 只安装 Meta 内核

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/install.sh | sh -s -- --core-only
```

### 跳过服务重启

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/install.sh | sh -s -- --skip-restart
```

### 跳过软件源更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/install.sh | sh -s -- --skip-opkg-update
```

---

## 脚本参数

```text
--plugin-only       只安装/更新 OpenClash 插件，不安装 Meta 内核
--core-only         只下载并安装 Meta 内核，不安装/更新插件
--skip-restart      完成后不尝试重启 openclash / uhttpd
--skip-opkg-update  跳过软件源更新
-h, --help          显示帮助
```

---

## 安装脚本会做什么

安装脚本会自动执行以下流程：

1. 检测当前系统包管理器
2. 检测当前防火墙模式
3. 输出当前系统架构和版本信息
4. 检测当前已安装的 OpenClash 版本
5. 安装 OpenClash 所需依赖
6. 获取 OpenClash 最新发布包
7. 自动下载并安装插件
8. 自动识别 CPU 架构
9. 自动下载并安装匹配的 Meta 内核
10. 可选重启相关服务

---

## 适用环境

理论适用于：

- OpenWrt
- iStoreOS
- ImmortalWrt
- 其它兼容 `opkg` / `apk` 的类 OpenWrt 系统

---

## 风险与注意事项

- 本脚本会调用系统包管理器安装依赖
- 会写入 `/etc/openclash/core/`
- 依赖 GitHub API 与 OpenClash 核心下载地址可访问
- 个别精简固件的软件包名称可能不完全一致，需要按环境自行微调
- 卸载脚本默认只移除 OpenClash 插件与 Meta 内核，不主动删除 `/etc/openclash` 配置目录，避免误删订阅和配置

---

## 为什么这个版本更适合公开分享

相比临时拼接版，这个仓库版本做了这些增强：

- 结构更清晰，适合 GitHub 首页展示
- 安装、更新、卸载职责拆分
- 安装脚本支持参数模式
- 日志输出更清楚，便于排障
- 自动识别当前已安装版本和最新发布标签
- 出错时更容易定位问题

---

## 后续计划

接下来还可以继续增强：

- 增加 `menu.sh` 菜单管理脚本
- 增加更多平台兼容提示
- 增加 GitHub Actions 语法检查
- 增加更完整的回滚与修复逻辑

---

## 致谢

- OpenClash: <https://github.com/vernesong/OpenClash>
- 博客思路来源：<https://naiyous.com/10947.html>
