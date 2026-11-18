# 入口并发与清理修复验证（2026-11-18）

基线：`9a576f1e67512c1f6c6d932191ba3c6a7fd27661`。本次更新维护安装/更新入口，不新增插件，不修改 README、已有 Release、软件源配置、插件配置或核心架构选择规则。没有访问或更新用户路由器。

## 已复现并修复

| 问题 | 复现与验收 |
| --- | --- |
| 未持锁任务删除其他任务的锁/临时文件 | 七个安装器逐项测试已有空锁与含文件锁，连续两次争用都必须失败并保留原文件；四个提供帮助参数的安装器另测 `--help`。六个缺少锁归属检查的入口补齐保护，daed 原有保护保留。 |
| INT / TERM 只清理、不退出 | 七个安装器分别注入正常退出、失败退出、INT、TERM；信号后不得继续执行，退出码为 130 / 143，所有持有的锁和专用下载目录被清理。 |
| 菜单/检查器/兼容更新入口共享临时文件 | 两个真实进程分别写入不同子脚本/版本标记，在同时放行后必须分别读取自己的结果；覆盖菜单、检查器、`update.sh` 和两个 PassWall 兼容入口。 |
| PassWall 临时包登记在命令替换中丢失 | 使用真实 `download_pkg_from_dir` + `PKG="$(...)"` + `cleanup` 复现包残留。将主包、语言包和 lyaml 回退包存入锁保护的专用目录，不依赖子 shell 将 TMPFILES 传回父进程；PassWall / PassWall2 的同名包不再共用路径。 |
| 旧入口仅支持 curl、空下载可被执行 | 三个兼容入口分别测试 curl、仅 wget、curl 失败后 wget 回退，覆盖下载失败（留有部分文件）、空响应、子任务退出 23、正常完成。错误/空响应不能执行，非零退出码保留，独立临时目录退出后删除。 |
| 镜像与检查参数未贯通 | 下载测试核对 `OPENCLASH_AUTO_BASE_URL` 覆盖后的真实请求 URL；`update.sh --check --skip-restart` 必须向子脚本传入检查、跳过索引及附加参数。 |

这些回归以真实脚本/函数运行，下载器和目标包管理器使用受控替身；它们验证入口行为，不等于路由器安装或服务运行测试。修复前的基线能复现锁丢失、信号后继续、共享文件串读和空下载问题；PassWall 包清理单独先失败、修复后通过。

## 本轮检查结果

```sh
python3 -m unittest discover -s tests -v
TEST_SHELL='busybox ash' python3 -m unittest discover -s tests -v
for f in *.sh; do sh -n "$f" || exit; busybox ash -n "$f" || exit; done
shellcheck *.sh
git diff --check
```

- POSIX sh（dash）与 BusyBox ash：各 26 项测试通过，参数化用例覆盖上述边界；不是仅通过语法检查。
- 14 个 shell 脚本的 sh / ash 语法及 ShellCheck 0.11.0 通过。
- 测试使用临时目录和下载替身，没有执行联网下载的安装脚本或宿主机包安装。

## 当前上游核对

| 组件 | 本次查询的上游发布 | 代码核对范围 |
| --- | --- | --- |
| OpenClash | [v0.48.002](https://github.com/vernesong/OpenClash/releases/tag/v0.48.002) | IPK/APK；真实 API 与 latest/expanded_assets HTML 均选中正确包；Meta/Smart 核心资产目录核对。 |
| PassWall | [26.11.11-1](https://github.com/Openwrt-Passwall/openwrt-passwall/releases/tag/26.11.11-1) | 当前 IPK/APK 主包的真实 API/HTML 选择通过；APK 安装仍走签名源。 |
| PassWall2 | [26.11.11-1](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases/tag/26.11.11-1) | 当前 IPK/APK 主包的真实 API/HTML 选择通过；APK 安装仍走签名源。 |
| Nikki | [v1.26.2](https://github.com/nikkinikki-org/OpenWrt-nikki/releases/tag/v1.26.2) | 24.10/25.12 分支资产名称与架构列表；官方 feed/install helper 可获取，未执行。 |
| SmartDNS | [Release48.5-RC1](https://github.com/pymumu/smartdns/releases/tag/Release48.5-RC1) | 现有 latest 端点当前指向带 RC 名称的版本；按实际包格式与架构核对，不称为稳定版测试。 |
| MosDNS | [v5.3.4-r15](https://github.com/sbwml/luci-app-mosdns/releases/tag/v5.3.4-r15) | 按 ABI 与 24.10/25.12 SDK 核对归档名称。 |
| daed | [v2.1.1](https://github.com/daeuniverse/daed/releases/tag/v2.1.1) / [OpenWrt 专用 daed_2026.07.31-r1](https://github.com/QiuSimons/luci-app-daed/releases/tag/daed_2026.07.31-r1) | 通用核心映射与 OpenWrt APK 架构包分别记录；不混用版本来源。 |

OpenClash、PassWall、PassWall2 共 12 项真实 API/HTML 资产选择通过。JSON 读入使用测试 jsonfilter 替身，标签/包选择和 HTML 解析使用原 shell 函数；固定输入快照与可写输出目录分离。现有自动解析能识别这些发布，不需要将插件版本写死在安装器里。

SourceForge PassWall 公钥 SHA-256 仍为 `52802b143489214e13b78f96599a147a638205cc22d9dd6d71229504e38ddc00`，与代码固定摘要一致。这只是公钥来源核对，本轮没有实际读取所有架构签名源包的目标版本或进行新的签名事务/依赖安装；不将 GitHub 发布版本冒充 APK 签名源的实际安装版本。BTF 源首页可达不代表某固件存在匹配 BTF 包。

## 固件、架构与验证边界

[官方发布目录](https://downloads.openwrt.org/releases/)当前正式分支为 25.12.6 / 24.10.8。重新枚举官方 packages 目录：25.12.6 的 35 个 ABI、24.10.8 的 36 个 ABI，共 71 项元数据核对，逐项记录 OpenClash/SmartDNS/daed 映射以及 Nikki/MosDNS 发布资产是否存在。缺失映射/资产明确留空，**有资产不等于安装成功或核心兼容**；PassWall 依赖覆盖也不能从通用 LuCI 包推定。

[iStoreOS OTA](https://fw.koolcenter.com/iStoreOS/x86_64/version.latest.v2) 本次查询 x86_64、armsr、r4s、rpi4、rpi5 均指向 25.12.6-2026110611；[seed-ac1 目录](https://fw.koolcenter.com/iStoreOS/seed-ac1/)最新镜像为 25.12.6-2026111216，但该设备目录未提供 `version.latest.v2`（404），不能声称核验了它的 OTA 元数据。未把 alpha/SNAPSHOT 混作正式固件。

本轮没有重新构建并实际安装所有架构固件，也没有新做核心执行、daed eBPF/内核服务、HTTP 面板或透明代理数据面验证。此前的 [10 月 7 日安装矩阵](validation-multiarch-2026-10-07.md) 和 [10 月 22 日 OpenClash 更新测试](validation-openclash-update-2026-10-22.md) 保留原日期与边界，不能视为当前所有上游新包的兼容证明。ARMv4/ARM 大端/PowerPC 的 OpenClash 核心缺失、x86 SSE2、MIPS/glibc、内核 BTF 和模拟器限制仍以旧报告为准，本次没有扩大支持声明。

## 已有 Issues / PR 对照

- [#34](https://github.com/slobys/openclash-auto-installer/issues/34) 日志使用 `04312fd`，主线已有 PassWall2 依赖补装；与本轮锁修复不是同一问题。没有报告者新回测，不擅自关闭 Issue。
- [#33](https://github.com/slobys/openclash-auto-installer/issues/33) 同样为旧脚本的 `vmlinux-btf` 包记录缺失，主线已有固件能力登记处理；本轮不声称重新验证其设备内核。
- [PR #28](https://github.com/slobys/openclash-auto-installer/pull/28) 的依赖方向主线已有对应实现；不在本次维护中自动合并旧补丁。
- [#35](https://github.com/slobys/openclash-auto-installer/issues/35) 的 Open-Box 集成为新功能请求，本次没有新增未经验证的安装器。

来源 URL、快照摘要、当前发布、源码摘要和 71 项元数据见 [机器可读报告](validation-maintenance-2026-11-18.json)。没有创建新 Release/标签。
