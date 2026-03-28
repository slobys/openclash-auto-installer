# OpenClash Auto Installer

一个适用于 OpenWrt / iStoreOS / ImmortalWrt 的 **OpenClash 一键安装 / 更新脚本**。

它会自动完成：

- 检测当前系统包管理器（`opkg` / `apk`）
- 检测防火墙栈（`fw4/nft` 或 `iptables`）
- 安装 OpenClash 所需依赖
- 获取 OpenClash 最新发布版本
- 自动下载并安装对应插件包
- 根据 CPU 架构自动匹配 Meta 内核
- 将内核安装到 `/etc/openclash/core/clash_meta`

> 适合想快速部署 OpenClash、减少手动操作、同时保留较好兼容性的用户。

---

## 功能特点

- 一键安装或更新 OpenClash
- 自动加锁，避免重复执行
- 自动识别 x86_64 / arm64 / armv7 / armv6 / armv5
- x86_64 自动识别 v1 / v2 / v3 / v4 指令级别并降级回退
- 插件安装成功但内核匹配失败时，不会直接报死，保留手动处理空间
- 输出过程清晰，便于排查

---

## 使用方法

### 方法一：直接执行远程脚本

先把脚本放到你自己的 GitHub 仓库或可直链访问的位置，然后执行：

```sh
curl -fsSL https://raw.githubusercontent.com/<your-name>/<your-repo>/main/install.sh | sh
```

或：

```sh
wget -qO- https://raw.githubusercontent.com/<your-name>/<your-repo>/main/install.sh | sh
```

### 方法二：先下载再执行

```sh
curl -fsSL -o openclash-install.sh https://raw.githubusercontent.com/<your-name>/<your-repo>/main/install.sh
chmod +x openclash-install.sh
sh openclash-install.sh
```

---

## 本地部署到路由器

如果你想按你博客里的形式写入到系统命令路径，可执行：

```sh
cat >/usr/bin/openclash-auto-install.sh <<'EOF'
# 这里替换为 install.sh 的完整内容
EOF

chmod +x /usr/bin/openclash-auto-install.sh
/usr/bin/openclash-auto-install.sh
```

---

## 脚本流程说明

1. 检测当前系统支持的包管理器
2. 判断防火墙环境是 `nft` 还是 `iptables`
3. 安装 OpenClash 依赖
4. 调用 GitHub Releases API 获取最新版插件包
5. 自动安装插件
6. 识别设备架构并尝试匹配 Meta 内核
7. 解压并安装到 OpenClash 核心目录

---

## 适用环境

理论适配以下环境：

- OpenWrt
- iStoreOS
- ImmortalWrt
- 其它兼容 `opkg` 或 `apk` 的类 OpenWrt 系统

---

## 风险提示

请在使用前注意：

- 脚本会安装依赖包并写入 `/etc/openclash/core/`
- 脚本依赖 GitHub API 与 OpenClash 核心下载地址可访问
- 如果你的网络环境无法访问 GitHub，可能导致版本获取或下载失败
- 个别精简固件可能缺少某些软件包，需按实际环境调整依赖列表

---

## 为什么做了这些优化

相比你原始脚本，这个版本主要做了这些整理：

- 增强了函数化结构，后续维护更方便
- 把临时文件统一放到独立目录，便于清理
- 增加了统一日志、警告、错误输出
- 优先检测 `opkg`，兼容性判断更稳
- 下载逻辑统一封装，减少重复代码
- README 单独拆出，更适合公开发布到 GitHub

---

## 后续可继续增强的方向

如果你愿意，我后面还可以继续帮你补：

- `update.sh`：只做升级逻辑
- `uninstall.sh`：卸载 OpenClash 与可选残留清理
- `menu.sh`：菜单式管理入口
- `LICENSE`
- `CHANGELOG.md`
- GitHub Actions 自动同步/检查脚本语法

---

## 致谢

- OpenClash 项目：<https://github.com/vernesong/OpenClash>
- 你的博客思路来源：<https://naiyous.com/10947.html>
