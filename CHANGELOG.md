# Changelog

## Unreleased — 2026-11-18

- 修复 OpenClash、PassWall、PassWall2、Nikki、SmartDNS、MosDNS 的锁清理归属：未获取锁的第二个任务、帮助和错误参数不再释放其他任务的锁或删除其临时文件。
- PassWall / PassWall2 将包文件收拢到锁保护的专用目录，修复命令替换子 shell 中 `register_tmp` 状态丢失导致安装包残留，并避免两个插件的同名依赖包互相覆盖。
- 七个安装器及菜单/检查/更新入口收到 INT / TERM 后分别以 130 / 143 退出，由 EXIT 统一清理，避免清理后继续安装。
- 菜单动作、commit 查询、更新检查和三个兼容更新入口改用独立临时目录，避免并发覆盖下载结果；退出后清理本次目录。
- `update.sh`、`auto-download-pro.sh`、`test-auto-download.sh` 增加 wget 和 curl 失败后的 wget 回退，拒绝下载失败/空文件，保留子任务失败状态；支持 `OPENCLASH_AUTO_BASE_URL` 镜像覆盖，检查模式保留附加参数。
- 新增真实入口的并发、锁归属、信号、下载器与失败传播回归；本轮 26 项测试在 POSIX sh / BusyBox ash 均通过。核对当前上游发布、12 项真实 API/HTML 资产选择及 71 项官方 ABI 元数据；不将元数据检查冒充全架构安装/内核实测，详见 `docs/validation-maintenance-2026-11-18.md`。

## Unreleased — 2026-10-22

- 修复 OpenClash 在 `apk update` 仅部分索引失败时被 `set -e` 提前中断：警告后检查已安装依赖并尝试现有索引，真正缺失依赖安装失败仍明确停止，不修改或禁用用户软件源。
- APK 路径只安装缺失的最小依赖，避免更新已有插件时无谓重装依赖。
- 安装后核验实际包版本与本次目标发布版本；版本为空、仍为旧版或核心安装失败时不再输出“完成”。
- 交互菜单在子脚本失败后显示退出码并保留返回菜单入口；非交互调用仍返回失败状态，空下载脚本不再被执行。
- 增加部分索引失败、缺失依赖、完整更新入口、版本未变化、核心失败和菜单错误处理的离线回归测试。

## v1.3.1 — 2026-10-07

- 将验证扩展至 OpenWrt 25.12.5 全部 35 个 CPU/ABI、24.10.8 全部 36 个 CPU/ABI，以及 6 个 iStoreOS 原始镜像，发布逐项结果和明确的未通过/未验证边界。
- OpenClash 按固件用户态 ABI 优先匹配核心，补齐 x86 32 位、MIPS 大小端、RISC-V、LoongArch 及 ARM 子架构；不再把内核位数当用户态位数。
- OpenClash 核心运行检查通过后才替换旧核心；无匹配核心或下载失败返回非零。修复 API 失败后的残缺 JSON 和 HTML 路由占位符误识别。
- 所有安装、更新检查、修复及卸载入口优先识别有效 APK 数据库，修复 iStoreOS seed-ac1 残留 opkg 导致包管理器误选。
- SmartDNS 修正 MIPS64 小端映射，拒绝 ARMv4/ARM 大端错误匹配；新增核心运行检查，避免包安装成功却不能运行仍报完成。
- daed 通用回退补齐版本标签；替换核心和停止旧服务前检查二进制是否可执行，拒绝依赖缺失的通用 MIPS/glibc 核心。
- 补充 ARM64 iStoreOS 官方内核下 daed 的进程、2023 面板及保留配置/启用状态升级验证；离线回归扩展至 15 项。

## v1.3.0 — 2026-10-07

- 重新验证 OpenWrt 25.12.5、24.10.8 和 iStoreOS 25.12.5-2026092410 的 x86_64 安装路径，发布固件与插件验证报告。
- PassWall / PassWall2 在 APK 环境使用官方签名源，固定公钥摘要、预下载事务软件包并检查最终包记录；签名源版本与 GitHub 不同时明确提示。
- Nikki 官方脚本改为下载成功且非空后再执行，修复网络失败被管道掩盖而误报安装成功；提前拒绝上游不支持的固件分支，APK 保持签名校验。
- daed APK 更新检测与安装统一跟随 OpenWrt 专用构建，不再与通用 daed Release 混比。
- 更新检测保留包修订号，修复 PassWall2 等 `r1` 到 `r2` 的更新漏报。
- 新增离线回归测试和 CI 检查，并将以下此前 main 上的兼容性修复纳入正式 Release。


- 修复 PassWall / PassWall2 只安装 LuCI 包、未补齐上游构建目录中的必需运行依赖，导致 iStoreOS 出现 `tcping`、`geoview`、`chinadns-ng`、`dns2socks` 等缺失的问题；现在优先使用系统软件源，缺失时按当前版本和架构从官方构建目录补齐。
- PassWall 安装前会把基础 `dnsmasq` 安全切换为其硬依赖的 `dnsmasq-full`；`opkg` 环境先完成覆盖安装再移除旧包，避免下载过程中提前失去本机 DNS。
- OpenClash 的 `opkg` 首装路径同步修复 `dnsmasq` / `dnsmasq-full` 文件冲突；PassWall、PassWall2 与 OpenClash 在 `apk` 环境改用 manifest 读取已安装版本，避免安装成功后显示 `unknown`。
- PassWall2 主包与中文包改为优先使用 GitHub 最新 Release assets，并保留 SourceForge 兜底，避免滚动目录与 Release 版本错配。
- 修复 OpenWrt 25.12 固件已内置 BTF 文件、但 `apk` 没有 `vmlinux-btf` 包记录时 daed APK 仍被依赖解析拒绝的问题；仅在确认 BTF 文件实际存在时登记同名兼容元包，不覆盖固件 BTF 文件。
- daed 下载增加 IPv4 回退；版本查询失败时明确检查 GitHub DNS、IPv4 默认路由和代理状态，避免把网络故障误报为“没有正式版本”。
- 更新检查器同步增加 IPv4 与 daed Release 页面兜底；GitHub API 限流时仍可识别最新正式版本。
- 修复 SmartDNS 在单行 GitHub API JSON 下只解析到最后一个资产、误报当前架构无安装包的问题。
- 适配 MosDNS `v5.3.4-r12` 新增的 `geo2txt` 硬依赖，按 Release 内置顺序在 LuCI 主包之前安装。
- SmartDNS、MosDNS 与 Nikki 在 OpenWrt 25.12 `apk` 环境统一从 manifest 读取安装后版本；Nikki 25.12 官方 feed 已验证可用，不再显示过时的“可能尚未完全适配”警告。
- 修复 ImmortalWrt / 精简 OpenWrt 首装环境缺少 `curl` 时无法打开菜单的问题；README 主入口改为 `wget` 下载菜单到 `/usr/bin/openclash-menu` 后执行，`menu.sh` 和 OpenClash 安装流程支持 `curl/wget` 双下载器，并新增 Gitee 原始文件入口。
- 新增 `daed.sh`，从 `daeuniverse/daed` 官方 Release 安装 / 更新 daed 静态二进制、GeoIP/GeoSite 数据与 OpenWrt procd 服务。
- 菜单、更新检测和安全卸载新增 daed 入口；安装前检查架构、Linux 5.17+、eBPF/BTF 内核能力及磁盘空间。
- daed 最新版本检测仅匹配正式 `v*` Release，避免被同仓库的 `dae-lang-core` 等组件 Release 干扰。
- daed 默认集成 `QiuSimons/luci-app-daed` 与中文包，安装后可从 LuCI“服务 → DAED”启停、查看日志和打开仪表板；OpenWrt 24.10 / 25.12 分别自动匹配 `ipk` / `apk`。
- daed 全新安装时 LuCI“启用”选项默认不勾选，等待用户手动启用；安装结束时不再额外停止或禁用服务，需要自动启用并启动时可显式传入 `--start`。
- daed 安装前新增 BTF 文件检查，支持 OpenWrt 25.12.4 `apk` 环境，但会拒绝缺少内置 BTF 或匹配 `vmlinux-btf` 的官方原版/裁剪固件，避免安装成功后无法运行。
- 根据官方原版 OpenWrt 实机测试完善 daed 的 BTF 报错与文档，明确包管理器兼容不等于内核兼容，且外置 `vmlinux-btf` 必须针对当前固件与内核自行构建。
- daed 在 OpenWrt 25.12 `apk` 环境缺少内置 BTF 时，会从上游推荐的软件源按系统架构自动查找并安装外置 `vmlinux-btf`；完整内核版本不一致时必须由用户确认。
- 修复 OpenWrt 25.12 上 LuCI DAED 界面因缺少包管理器记录中的 `daed` 依赖而安装失败；现在会同时安装匹配架构的上游 daed APK，并明确 2023 面板仅在服务启用并启动后可访问。
- 修复 OpenWrt 25.12 安装上游 daed APK 后又被通用静态核心和自定义服务脚本覆盖的问题；25.12 现在完整使用上游 OpenWrt 包，并在自动启动时检查进程是否能持续运行及输出崩溃日志。
- daed 更新时会重启并验证原本已启用的服务；识别旧核心 `local_tcp_sockops` 使用 `bpf_get_current_task` 的不兼容错误，并限制失败重试、自动取消启用，避免持续崩溃刷日志。
- 修复 OpenWrt 25.12 使用 `apk del daed` 时因 LuCI 反向依赖保留旧核心、后续同版本 APK 未覆盖的问题；现在会同时移除三个相关包、确认旧核心已删除，并清空历史日志后验证新核心。

## v1.2.5

- 修复 PassWall 安装 / 更新时只从 SourceForge 目录抓包导致无法安装 GitHub 最新 release 的问题；`passwall.sh` 现在优先匹配 GitHub release assets（如 `26.5.20-1` 的 `23.05-24.10_*` / `25.12+_*` 包），下载时带 `gh-proxy.com` 兜底，失败后再回退 SourceForge 目录。
- 修复 GitHub API 触发 rate limit 或临时不可用时 PassWall 仍可能拿不到最新 release assets 的问题；`passwall.sh` 现在会解析 GitHub release 页面和 `expanded_assets` 作为兜底。

## v1.2.4

- 修复 `check-updates.sh` 在 OpenWrt 25.12+ / `apk` 环境下版本读取不完整的问题：依次从 `apk list --installed --manifest`、`apk list --installed`、`apk info -v/-a` 读取版本。
- SmartDNS / MosDNS / Nikki 检测增加 LuCI 包与核心包的候选包名兜底，避免 LuCI 菜单已存在但版本检测为空。
- MosDNS 优先读取 `mosdns version`，避免把 `luci-app-mosdns` 的界面包版本误当成 MosDNS 核心版本；SmartDNS 避免把软件包版本和 GitHub Release 标签直接比较。

## v1.2.3

- 修复 `check-updates.sh` 在 OpenWrt 25.12+ / `apk` 环境下误判已安装插件为 `not installed` 的问题：改用 `apk info -e` 判断安装状态，并读取已安装版本。

## v1.2.2

- `passwall.sh` / `passwall2.sh` 支持 OpenWrt 25.12+ / `apk` 环境：自动匹配上游 `packages-25.12` 目录并下载 `.apk` 安装包
- `uninstall.sh` 同步优化 `apk` 环境卸载提示，失败时给出正确的 `apk del` 手动命令
- `nikki.sh` 在 `apk` 环境改为导入 Nikki 官方 `openwrt-25.12` feed 后安装，不再错误依赖 OpenWrt 官方源自带 Nikki 包
- Nikki 卸载同步移除 `nikki` / `mihomo-meta` 主运行包，避免只卸载 LuCI 后残留核心包
- `mosdns.sh` 修复 GitHub API 403 兜底逻辑：改为解析 latest tag 后拉取 `expanded_assets`，确保能找到 25.12 架构包
- `check-updates.sh` 支持在 `apk` 环境下检测已安装 PassWall / PassWall2 版本，并改为 curl/wget 双栈获取最新版本，减少精简固件漏检
- `install.sh` 新增通用 `--skip-pkg-update` 参数，菜单与 `update.sh` 同步改用该参数，旧的 `--skip-opkg-update` 保留兼容
- `update.sh` 下载地址从旧 `master` 分支修正为当前 `main` 分支
- `auto-download-pro.sh` / `test-auto-download.sh` 改为兼容包装器，避免旧的 24.10/aarch64/opkg 固定逻辑在 25.12+ 下误用
- README 同步更新 PassWall / PassWall2 的 `apk` 兼容说明

## v1.2.1

- 优化 OpenClash 安装阶段的 `opkg update` 容错：当 Nikki / PassWall 等第三方 feed 临时不可用时，不再直接中断 OpenClash 安装流程，而是警告后继续尝试安装依赖
- 优化 MosDNS 安装阶段的 GitHub Release 获取逻辑：当 GitHub API 返回 403 或临时不可用时，自动回退到 releases 页面解析下载地址

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
