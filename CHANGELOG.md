# Changelog

## v1.2.0

- 新增 `mosdns.sh`，支持从 `sbwml/luci-app-mosdns` GitHub Release 安装 / 更新 MosDNS 与 LuCI 界面
- `menu.sh` 新增 MosDNS 安装、更新检测与安全卸载入口
- `check-updates.sh` 新增 MosDNS 最新版本检测
- `uninstall.sh` 新增 MosDNS 安全卸载，默认保留 MosDNS 配置文件
- README 同步补充 MosDNS 使用方式、限制说明与项目文件列表

## v1.1.9

- 修复 SmartDNS 卸载时未先移除 `app-meta-smartdns`，导致 `luci-app-smartdns` 被依赖阻止卸载的问题
- 优化菜单脚本下载逻辑：先解析最新 commit SHA，再用固定提交地址下载子脚本，避免 GitHub raw 分支缓存返回旧文件
- README 一键命令改用 jsDelivr 地址，降低 raw 缓存影响
- 优化菜单交互：从二级菜单返回主菜单时不再额外要求按一次回车

## v1.1.8

- 新增 `smartdns.sh`，支持从 SmartDNS 官方 GitHub Release 安装 / 更新 `smartdns` 与 `luci-app-smartdns`
- `menu.sh` 新增 SmartDNS 安装、更新检测与安全卸载入口
- `check-updates.sh` 新增 SmartDNS 最新版本检测
- `uninstall.sh` 新增 SmartDNS 安全卸载，默认保留 `/etc/config/smartdns`
- README 同步补充 SmartDNS 使用方式、限制说明与项目文件列表

## v1.1.7

- `passwall.sh` / `passwall2.sh` 增加系统版本兼容映射，优先按 22.03 / 23.05 / 24.10 三档匹配上游构建目录，减少 24.10.x、25.x 和第三方固件版本号导致的软件源路径错误
- `passwall.sh` / `passwall2.sh` 在依赖不兼容、架构不匹配、第三方固件软件源异常时，输出更明确的排障提示
- `nikki.sh` 在 `iptables` 环境下输出更直接的限制说明，明确该插件仅支持 `firewall4/nftables`
- `README.md` 同步补充高风险环境说明和当前脚本的兼容策略

## v1.1.6

- 优化 README 首页结构，补充“适合谁 / 不适合谁”“推荐使用方式”“支持矩阵”“已知限制”等导航信息
- 强化项目首页对 OpenClash 主入口定位的表达，同时明确 PassWall / PassWall2 / Nikki 的脚本集合属性
- 补充项目文件列表，完善对 `check-updates.sh`、`auto-download-pro.sh`、`test-auto-download.sh` 的说明可见性
- 文档层面进一步提升 GitHub 首页可读性，方便新用户快速判断适用环境与使用入口

## v1.1.5

- `passwall.sh` / `passwall2.sh` 安装逻辑瘦身，改为更接近官方 IPK 的安装方式
- 默认仅添加 feed / key、刷新源并安装主包与中文语言包，不再主动做额外依赖补装或配置修复
- `nikki.sh` 保留官方 feed.sh / install.sh 安装路径，仅保留必要检测与轻刷新逻辑
- 安装阶段统一改为“少做决定”，降低脚本额外干预带来的不稳定因素

## v1.1.4

- 菜单卸载入口统一改为“安全卸载”，仅移除主包并删除对应配置
- 新增 `uninstall.sh` 通用安全卸载流程，覆盖 PassWall / PassWall2 / Nikki / OpenClash
- 移除“完整卸载 / 彻底清理”方向的默认设计，避免误删共享依赖导致重装异常
- `menu.sh` 非交互参数统一改为 `--uninstall-*`

## v1.1.3

- 修复 `full-uninstall.sh` 中卸载 OpenClash 时误删共享核心包（如 `xray-core`）的问题
- 现在 `full_uninstall_openclash` 仅移除 OpenClash 特有包（`luci-app-openclash`、`mihomo`、`clash`、`clash-meta`），避免影响其他插件

## v1.1.2

- 增强 OpenWrt 25.12+ 兼容性检测与提示
- `nikki.sh` 增加防火墙栈检测，若系统为 iptables（非 firewall4）则提前报错，避免 Nikki feed.sh 失败
- `nikki.sh` 增加 apk 包管理器警告，提示 OpenWrt 25.12 下可能尚未完全适配
- `passwall.sh` / `passwall2.sh` 增加 apk 包管理器检测，若为 apk 则报错（脚本尚未适配）
- `install.sh` 增加 OpenWrt 25.12 版本检测与提示，帮助用户识别潜在兼容问题

## v1.1.1

- 新增独立脚本 `check-updates.sh`，用于检测 OpenClash / PassWall / PassWall2 / Nikki 是否有新版本
- `check-updates.sh` 仅做检测，不执行更新，便于继续使用原有更新方式
- `install.sh` 新增 `--check-update`，可仅检测 OpenClash 是否有新版本，不自动执行更新
- `update.sh` 新增 `--check` / `--check-update` 入口，便于快速检查更新
- `menu.sh` 新增“检查所有插件是否有新版本”和“检查 OpenClash 是否有新版本”菜单项
- README 补充更新检测用法说明

## v1.1.0

- 新增 `passwall.sh`，支持安装 / 更新 PassWall
- 新增 `passwall2.sh`，支持安装 / 更新 PassWall2
- 新增 `nikki.sh`，支持安装 / 更新 Nikki
- 扩展 `menu.sh` 为多插件管理入口，支持 OpenClash / PassWall / PassWall2 / Nikki
- 更新 README，改为脚本集合项目说明

## v1.0.6

- 优化 `opkg update` 失败处理：检测锁文件后自动等待并重试一次
- 增强错误提示，明确建议使用 `--skip-opkg-update` 进行重试
- 修正 OpenClash 安装状态识别逻辑，减少已安装场景被误判为 `not installed`
- 安装完成后同时输出当前插件版本与当前 Meta 内核版本

## v1.0.5

- `install.sh` 新增普通 Meta / Smart Meta 核心通道选择能力
- 默认支持自动判断核心通道，并可通过 `--meta-core` / `--smart-core` 强制指定
- 下载逻辑改为基于 OpenClash `core` 分支中的 `master/meta` 与 `master/smart` 真实目录结构

## v1.0.4

- `install.sh` 安装完成后增加实际 Meta 内核版本输出，便于确认真实安装结果
- 优化完成提示，说明 LuCI 页面版本显示可能滞后于命令行结果
- `uninstall.sh` 增加安装状态判断，避免未安装时输出不必要错误

## v1.0.3

- 精简 README，移除偏包装、偏宣传和非项目运行所需的描述
- README 调整为更聚焦功能、命令、参数、兼容性与文件说明

## v1.0.2

- 移除与项目运行无关的对外发布文案文件，保持仓库聚焦项目本身
- 精简 README 中对非项目文件的引用

## v1.0.1

- 优化 README 首页展示，新增徽章与更清晰的功能概览
- 项目文案层面进一步增强公开分享可用性

## v1.0.0

- 新增 `repair.sh`，用于执行基础修复流程
- 新增 GitHub issue 模板，方便反馈 bug 和功能建议
- 项目整体结构已整理为适合公开发布与长期维护的脚本仓库
- 补齐安装、更新、卸载、菜单、修复、文档、CI、License 等基础要素

## v0.4.1

- 修复 `menu.sh` 在 `curl ... | sh` 场景下无法正常读取交互输入的问题
- 菜单输入改为优先从 `/dev/tty` 读取
- 同步修正文档中的菜单执行方式说明

## v0.4.0

- 新增 `menu.sh`，提供菜单式管理入口
- 新增 `LICENSE`，补齐公开仓库基础文件
- 完善 README，增加菜单式使用与博客引用命令说明
- 项目结构进一步向可公开分享仓库形态完善

## v0.3.0

- 为 `install.sh` 增加参数模式：`--plugin-only`、`--core-only`、`--skip-restart`、`--skip-opkg-update`
- 增加当前已安装版本与最新发布标签输出
- 增加相关服务自动重启逻辑（可跳过）
- 优化更新脚本，默认复用安装脚本并跳过索引刷新
- 完善 README 的高级用法和参数说明

## v0.2.1

- 修复 `fetch_openclash_package_url()` 日志输出混入命令替换结果，导致下载 URL 异常的问题
- 保持日志可见，同时确保函数返回值纯净

## v0.2.0

- 调整仓库结构到根目录，更适合 GitHub 展示
- 新增 `update.sh`
- 新增 `uninstall.sh`
- 重写并完善仓库首页 README
- 保留 OpenClash 自动安装、升级与 Meta 内核自动匹配能力

## v0.1.0

- 初始发布
- 提供 OpenClash 一键安装 / 更新脚本
- 支持 `opkg` / `apk`
- 支持自动识别防火墙栈与 CPU 架构
- 支持自动下载并安装 Meta 内核
- 补充 README，方便直接发布到 GitHub
