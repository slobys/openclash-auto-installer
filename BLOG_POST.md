# OpenClash 一键安装/更新脚本发布文案

下面这份内容可以直接作为博客文章初稿使用，你可以按自己的口吻再微调。

---

## 标题建议

### 标题 1
2026 最新 OpenClash 一键安装/更新脚本，支持 iStoreOS / OpenWrt / ImmortalWrt

### 标题 2
OpenClash 全网更省心的一键安装方案：自动识别架构，自动安装 Meta 内核

### 标题 3
OpenClash 一键安装/更新/卸载脚本发布，适配 OpenWrt 与 iStoreOS

---

## 文章简介

很多朋友在安装 OpenClash 时，最头疼的其实不是插件本身，而是：

- 不知道该装哪个版本
- 不清楚当前固件到底用 `opkg` 还是 `apk`
- 不知道自己该下载哪个架构的 Meta 内核
- 安装完成后还要手动找内核、手动导入、反复折腾

所以我把这套流程整理成了一个更适合普通用户直接使用的脚本项目。

这个脚本目前支持：

- 一键安装 / 更新 OpenClash
- 一键卸载 OpenClash
- 菜单式管理
- 自动识别 `opkg` / `apk`
- 自动识别 `fw4/nft` 或 `iptables`
- 自动获取 OpenClash 最新版本
- 自动匹配并安装 Meta 内核
- x86_64 自动区分 v1 / v2 / v3 / v4

适用于：

- OpenWrt
- iStoreOS
- ImmortalWrt
- 其它兼容 `opkg` / `apk` 的类 OpenWrt 系统

GitHub 项目地址：

<https://github.com/slobys/openclash-auto-installer>

---

## 一键安装 / 更新命令

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/install.sh | sh
```

---

## 菜单式管理命令

推荐直接执行：

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/menu.sh)"
```

如果你的环境支持 `/dev/tty` 交互，也可以用：

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/menu.sh | sh
```

---

## 一键卸载命令

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/openclash-auto-installer/main/uninstall.sh | sh
```

---

## 支持的高级参数

### 只安装插件

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

---

## 使用说明

脚本执行后会自动完成以下步骤：

1. 检测系统包管理器
2. 检测防火墙环境
3. 安装相关依赖
4. 获取 OpenClash 最新发布包
5. 自动安装插件
6. 自动匹配 Meta 内核
7. 尝试重启相关服务

如果你的架构无法自动匹配，脚本也会保留插件安装结果，并提示你手动下载对应内核，不会直接把整个流程做死。

---

## 注意事项

- 需要你的系统能正常访问 GitHub
- 部分精简固件的软件包名称可能和标准源不同
- 卸载脚本默认不会主动删除 `/etc/openclash` 配置目录，避免误删订阅和配置
- 如果你自己改过 OpenClash 目录结构，建议先备份再使用

---

## 项目特点

相比单纯的临时命令，这个版本更适合长期维护：

- 仓库结构更清晰
- 支持安装 / 更新 / 卸载 / 菜单管理
- 有 README、CHANGELOG、LICENSE
- 增加了 GitHub Actions 自动检查 shell 脚本语法
- 更适合直接引用到博客或视频教程中

---

## 结尾建议文案

如果你想少折腾一点，直接用这个脚本就行。后面我也会继续把这个项目往更完整的一键脚本仓库方向维护，比如增加修复脚本、更多固件兼容提示、菜单功能增强等。

如果你在使用过程中遇到问题，也可以直接到 GitHub 仓库查看更新。
