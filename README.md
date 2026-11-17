# NSY G68-PLUS · iStoreOS 24.10 杂交固件（DSA 网络版）

[![Build](https://github.com/iiibeloved/istoreos-hybrid-g68/actions/workflows/build.yml/badge.svg)](https://github.com/iiibeloved/istoreos-hybrid-g68/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/iiibeloved/istoreos-hybrid-g68)](https://github.com/iiibeloved/istoreos-hybrid-g68/releases)

> **以 iStoreOS 24.10 官方为基座，移植 NSY G68 实机设备层；网络采用 RTL8367S DSA（lan1-4 / wan），并保留长按 Reset→MaskROM。**
> 保留 iStoreOS 的完整应用生态与更新节奏，同时获得 **长按 Reset 直接进 MaskROM** 的刷机体验——与 immortalwrt 固件完全一致的刷写方式：USB 双公头 + RKDevTool + 长按 Reset + **强制按地址写**。

---

## 为什么是"杂交"（Hybrid）

| 层 | 来源 | 说明 |
|---|---|---|
| **系统基座** | [iStoreOS 24.10 官方](https://github.com/istoreos/istoreos)（`istoreos-24.10`） | 内核 6.6、官方 feeds、完整软件包生态 |
| **设备层** | NSY G68 实机验证配置（DTS / u-boot / 分区 / 按键链路） | overlay 方式注入，不改 iStoreOS 源码树 |
| **应用生态** | iStoreOS 官方 + store/third feed | quickstart、商城、ksmbd、Docker 等随上游更新 |

不在 iStoreOS 里维护一份长期分叉的内核/设备树；设备层以**整文件 overlay** 交付，iStoreOS 升级时冲突面最小。

---

## 核心特点

- **长按 Reset → MaskROM（无需短接触点）**
  SPL 阶段读 SARADC 通道 0；按住 Reset 上电即写 BROM 下载标志并复位，RKDevTool 直接识别 MaskROM 设备。
- **全量 iStoreOS 包集（约 863 个包，含依赖展开）**
  quickstart、iStore 商城、Docker、ksmbd、NFS、下载/文件工具等一应俱全，不是裁剪版。实际数量见每次 Release 的 `packages.manifest`。
- **官方基准去重（硬规则）**
  以 iStoreOS 官方 defconfig / manifest 为唯一基准；第三方与官方**同名**或**同文件**冲突（`dnsmasq` vs `dnsmasq-full`、`libustream` 变体等）一律移除，保证上游更新后重建可预期。
- **中文条件投递，无孤儿菜单**
  `g68-i18n` 仅在检测到对应应用已安装时覆盖其界面文件，避免"装了中文包但菜单不存在"的孤儿项。
- **CI 硬件级审核**
  `hw-audit` 在编译前交叉核对 DTS ↔ 内核配置 ↔ 包集（DSA 交换机 / XPCS / adc-keys / 存储 / WiFi 豁免），缺关键项直接阻断构建。
- **三层核心守卫**
  u-boot 源码、应用后树、编译产物三处断言 `download key pressed`、`adc_channel_single_shot`、`BOOT_MODE_REG=0xfdc20200`，防止 MaskROM 能力被上游改动悄悄破坏。
- **可复现的构建记录**
  `upstream.lock`（`state` 分支）记录本次构建的 iStoreOS commit 与 packages/luci/store/third 等各 feed commit。

---

## 目标与不变量（DSA 版）

1. **基座 = 上游 iStoreOS 官方**（`istoreos-24.10`），每次构建 clone 最新提交；`upstream-watch` / `check-upstream` 在上游变化时自动触发构建；
2. **网络 = ABC 验证的 DSA 方案**（RTL8367S 5 口：lan1-4 + wan，CPU=gmac0 RGMII）；
3. **长按 Reset → MaskROM**：u-boot overlay（`boot_mode.c` + ADC defconfig + 板级 dts）与三层守卫，来自本杂交设备层；
4. **包集 = 全量 + 上游优先去重**：每次构建 `package-guard` 以上游 defconfig 为基准比对，重复项自动注释并回写；
5. **商城 / quickstart 必须跟随上游**：来自 store / packages / luci feeds，仓库内不固化、不做整文件覆盖；
6. **ABC 默认可用**：网络 dts 与 `local-mac-address` 保持 ABC 原样（不从仓库侧"优化"）；DSA 驱动直接用主线 6.6 原生 rtl8365mb（已原生支持 RTL8367S，与 ABC 覆盖版本逐字节一致），不再整文件覆盖驱动。

## 包去重规则（上游优先，强制）

1. **基准 = iStoreOS 官方包集**（目标 `make defconfig` 结果）；
2. 任何第三方/自定义包与官方**同名**或**同文件**或 **PROVIDES 同名** → **以上游为准**，第三方那条注释或删除；
3. 每次构建 `prepare` 阶段自动执行 `package-guard` 对照上游包清单，重复项自动注释并回写 `configs/`；
4. 典型例子：`dnsmasq-full`（PROVIDES dnsmasq）→ 本仓库显式选 `dnsmasq-full`、关闭 `dnsmasq`（二者互斥，`dnsmasq-full` 为本固件选定的 DNS/DHCP 实现）；`luci-ssl-openssl`/`libustream-openssl` → 保留基座变体；`samba4`、WiFi 栈不选。

## 商城 / quickstart 跟随上游

- `luci-app-store`（商城）来自上游 **store feed**（linkease/istore，main 分支）；
- `quickstart` / `luci-app-quickstart` 来自上游 **packages / luci feed**；
- 仓库内**不固化**这两者的代码或翻译覆盖（仅对无官方中文的第三方应用做条件 i18n）；
- 每次构建 `feeds update` 拉取最新上游版本；如与上游包重复，按去重规则**以上游为准**。

## 网络模型（RTL8367S DSA，5 口全用）

| 逻辑接口 | 硬件 | 角色 |
|---|---|---|
| `lan1` ~ `lan4` | RTL8367S port@0~3 | LAN（同一 br-lan，硬件转发） |
| `wan` | RTL8367S port@4 | WAN（DHCP / PPPoE） |
| `port@7 (cpu)` | → gmac0，RGMII fixed-link 1000 | 5 口共用的 CPU 上行 |

- 4 LAN + 1 WAN，**5 个网口全部可用**；
- 5 口共享 1Gbps CPU 上行（交换机内部互访不受限）；
- 首次启动后可用 `ip -br link` 查看 `lan1..lan4/wan`；插拔网线可确认物理口与逻辑口对应关系；
- dts 中的 `local-mac-address` 为 ABC 参考配置的默认值；LAN/WAN 接口 MAC 由板级脚本按 eMMC CID 生成覆盖（与 iStoreOS 默认行为一致）。

## 下载

**最新 Release**：<https://github.com/iiibeloved/istoreos-hybrid-g68/releases/latest>

| 资产 | 说明 |
|---|---|
| `istoreos-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz` | 固件镜像（约 **99.9 MiB**） |
| `sha256sums` | 镜像校验值 |
| `packages.manifest` | 本次构建的完整包清单（约 863 项） |

最新（`g68-hybrid-2026.11.14-r1`）：

```
sha256: 2952f78d6398a83538551ad9c7af2db8c37e9e12f6649afef41a733fe36adab0
```

### 国内加速

- `https://gh-proxy.com/https://github.com/iiibeloved/istoreos-hybrid-g68/releases/download/<tag>/<file>`
- `https://ghfast.top/https://github.com/iiibeloved/istoreos-hybrid-g68/releases/download/<tag>/<file>`
- `https://ghproxy.net/https://github.com/iiibeloved/istoreos-hybrid-g68/releases/download/<tag>/<file>`

---

## 刷机步骤

1. USB **双公头**线连接电脑与设备（OTG 口，靠网口侧 USB）
2. 安装 **RKDevTool v3.18** + **驱动 v5.12**
3. 设备断电 → **按住 Reset** 键 → 上电 → 松开 → RKDevTool 显示 **发现一个 MaskROM 设备**
4. 「高级功能」→ Boot 选择 `rk356x_spl_loader_v1.21.113.bin`
5. 「获取当前存储」→「**擦除所有**」
6. 「下载镜像」选择**解压后的 `.img`** → 勾选「**强制按地址写**」→ 执行

> **本仓库的 u-boot 已内置长按 Reset→MaskROM 支持**（overlay + 三层守卫），刷机时无需短接触点。
> 若长按无效，可用短接触点法兜底（BROM 模式，loader 相同）。
> 首次启动约 1–2 分钟，之后进入 iStoreOS 初始化向导。

### 分区布局

| 分区 | 大小 | 用途 |
|---|---|---|
| `uboot` | 16 MiB | u-boot / SPL |
| `kernel` | 16 MiB | 内核 + DTB（FIT） |
| `rootfs` | **500 MiB** | 只读 squashfs 系统 |
| `rootfs_data` | 4096 MiB | 可写 overlay（iStore/opkg、Docker 数据、配置） |

> 镜像文件约 100 MiB（squashfs 压缩后），`rootfs_data` 分区在首次启动时自动创建文件系统。

---

## 构建流水线

```text
iStoreOS 官方源 (istoreos-24.10)
        │  clone
        ▼
  apply-device.sh ──► 设备层注入（DTS / u-boot overlay / 内核补丁 / 分区 / i18n）
        │
        ▼
  selftest.sh ──► 静态自检（overlay / defconfig / 补丁 / DTS / 镜像定义）
        │
        ▼
  hw-audit.sh ──► 硬件级审核（DTS ↔ kernel-config ↔ 包集 ↔ u-boot defconfig）
        │
        ▼
  package-guard ──► 以官方包清单为基准去重（同名 / 同文件 / PROVIDES）
        │
        ▼
  uboot-check ──► 只编译 u-boot + 三层产物断言
        │
        ▼
  build ──► 全量编译 → 镜像 → 分区表校验 → artifact → Release → 回写 state 锁
```

| 作业 | 职责 |
|---|---|
| `check-upstream` | 对比上游 commit 与 `state` 锁，决定是否构建 |
| `prepare` | 应用设备层、静态自检、硬件审核、官方基准去重、回写去重结果 |
| `uboot-check` | 独立编译 u-boot，验证 MaskROM 链路（源码 / 应用后 / 产物） |
| `build` | 全量编译、镜像校验、Release 发布、`upstream.lock` 回写 |

触发方式：`push`（配置变更）、`workflow_dispatch`（手动）、`schedule`（每周检查）、`upstream-watch`（上游变化自动触发）。

---

## 仓库结构

```text
device/
  kernel-dts/            G68 内核设备树（SGMII/XPCS、DSA、adc-keys、eMMC）
  kernel-config/         内核配置片段（Realtek DSA 等）
  board.d/               板级网络映射 02_network_g68（不修改上游 02_network）
  kernel-patches/        910/911/913/914/915 内核补丁（915 为 SGMII MAC 选择修复）
  uboot/                 u-boot overlay（boot_mode、defconfig、板级 dts、版本守卫）
  i18n-overlay/          中文覆盖（28 个文件，条件投递）
  hw-exemptions.txt      硬件豁免清单（如 WiFi）
scripts/
  apply-device.sh        设备层注入（幂等，带版本守卫）
  selftest.sh            构建前静态自检
  hw-audit.sh            硬件级内容审核
  verify-maskrom.sh      MaskROM 三层守卫（repo / applied / built）
  package-guard.py       官方基准包去重
  check-partition-table.py  镜像分区表校验
configs/
  g68-hybrid.config      完整包配置：显式启用约 727 项，依赖展开后约 863 项（含目标 / 设备 / 分区）
.github/workflows/       build / maskrom-guard / package-guard / upstream-watch
```

---

## 不变量（任何改动都不得破坏）

1. **长按 Reset → MaskROM** 链路可用（三层守卫通过）；
2. **包集以 iStoreOS 官方为基准**去重，不保留会与官方冲突的第三方包；
3. **中文条件投递**：只在应用已安装时覆盖，不产生孤儿菜单；
4. **全量包集**（非裁剪版），WiFi 除外；
5. **上游只认 iStoreOS**，设备层以 overlay 交付。

---

## 注意事项 / 已知限制

- **本固件不使用 WiFi**：G68 的 MT7916 未启用（WiFi 栈整体不选），如需无线请勿刷此固件。
- **SMB 使用 ksmbd**：`samba4` 在新工具链上编译失败，已排除；SMB 共享由 ksmbd + `luci-app-ksmbd` 提供。
- **DNS/DHCP 使用 `dnsmasq-full`**：config 中显式选 `dnsmasq-full=y`、关闭 `dnsmasq`（二者互斥，`dnsmasq-full` 为本固件选定的 DNS/DHCP 实现）。
- **SSL 栈为 mbedtls**：不选 `luci-ssl-openssl`（会与基座 `libustream-mbedtls` 冲突）。
- **2.5G 口**：SGMII 走 fixed-link 1000 Mb/s（真机实测），非 2500 Mb/s。
- **main 分支受保护**：CI 的构建状态写入 `state` 分支的 `upstream.lock`，`check-upstream` / `upstream-watch` 优先读取该分支。
- **镜像需真机验收**：LAN/WAN、eMMC/USB、长按 Reset、中文界面与商城均建议实机确认。

---

## 本地构建

```sh
git clone --depth 1 -b istoreos-24.10 https://github.com/istoreos/istoreos.git
sh scripts/apply-device.sh istoreos          # 注入设备层
sh scripts/selftest.sh istoreos              # 静态自检
sh scripts/hw-audit.sh                       # 硬件审核
cp configs/g68-hybrid.config istoreos/.config
cd istoreos && make defconfig && make -j"$(nproc)"
```

产物：`istoreos/bin/targets/rockchip/armv8/*nsy_g68-plus*sysupgrade.img.gz`

---

## 故障排查

| 现象 | 处理 |
|---|---|
| 构建报 `check_data_file_clashes` | 按「官方基准去重」规则，移除日志中 `wants to install file` 的第三方包变体 |
| 构建报 `root.ext4 Error 1` / 空间不足 | 确认 `CONFIG_TARGET_ROOTFS_PARTSIZE` 为 500 |
| 长按 Reset 无反应 | 检查 Reset 键焊接/排线，或用短接触点法兜底进 MaskROM |
| 刷机后无法启动 | 重新「擦除所有」后按「强制按地址写」再刷；确认 loader 版本 |
| 商城/quickstart 无中文 | 确认已安装对应应用后重启（i18n 条件投递） |

---

## 致谢

- [iStoreOS](https://github.com/istoreos/istoreos) —— 系统基座与软件生态
- [immortalwrt](https://github.com/immortalwrt/immortalwrt) —— 设备层参考与验证经验
- 所有上游包维护者

> 本项目仅做设备层移植与 CI 编排，固件内容遵循各上游组件许可证。
