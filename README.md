# OpenClash Auto Installer

一个面向 **OpenWrt / iStoreOS / ImmortalWrt** 的 **OpenClash 一键安装 / 更新脚本项目**。

这个仓库的目标不是只放一段“能跑”的命令，而是提供一套更适合公开分享、维护和复用的脚本化交付方案。

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

## 使用方式

### 一键安装 / 更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/install.sh | sh
```

或者：

```sh
wget -qO- https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/install.sh | sh
```

---

### 单独更新

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/update.sh | sh
```

---

### 卸载 OpenClash

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/master/uninstall.sh | sh
```

---

## 适用环境

理论适用于：

- OpenWrt
- iStoreOS
- ImmortalWrt
- 其它兼容 `opkg` / `apk` 的类 OpenWrt 系统

---

## 安装脚本做了什么

安装脚本会自动执行以下流程：

1. 检测当前系统包管理器
2. 检测当前防火墙模式
3. 安装 OpenClash 所需依赖
4. 获取 OpenClash 最新发布包
5. 自动下载并安装插件
6. 自动识别 CPU 架构
7. 自动下载并安装匹配的 Meta 内核

---

## 风险与注意事项

- 本脚本会调用系统包管理器安装依赖
- 会写入 `/etc/openclash/core/`
- 依赖 GitHub API 与 OpenClash 核心下载地址可访问
- 个别精简固件的软件包名称可能不完全一致，需要按环境自行微调
- 卸载脚本默认只移除 OpenClash 插件，不主动删除你的订阅与配置备份（除非你手动扩展）

---

## 适合谁

这个项目适合：

- 想做博客教程分享的人
- 想给路由器快速部署 OpenClash 的用户
- 想做成 GitHub 项目长期维护的人
- 想把安装逻辑整理得更规范的人

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
