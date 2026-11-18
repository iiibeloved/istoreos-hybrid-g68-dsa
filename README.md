# NSY G68-PLUS · iStoreOS 杂交固件（DSA 网络版）

[![构建状态](https://github.com/iiibeloved/istoreos-hybrid-g68-dsa/actions/workflows/build.yml/badge.svg)](https://github.com/iiibeloved/istoreos-hybrid-g68-dsa/actions/workflows/build.yml)
[![最新 Release](https://img.shields.io/github/v/release/iiibeloved/istoreos-hybrid-g68-dsa)](https://github.com/iiibeloved/istoreos-hybrid-g68-dsa/releases/latest)

> 一句话简介：给 **农商云 NSY G68-PLUS（RK3568）** 用的完整 iStoreOS 固件，保留官方全部应用生态，并加入**长按 Reset 直接进 MaskROM** 的刷机体验；网络采用 Linux 主线 **DSA（rtl8365mb 驱动）**，把 5 个网口呈现为独立网卡 `lan1`~`lan4` 与 `wan`。

如果你是第一次接触本固件，建议只看下面四节即可完成刷机：**[固件特点](#二固件特点) → [刷机前注意事项](#四刷机前注意事项) → [刷机方法](#五刷机方法) → [刷机后注意事项](#六刷机后注意事项)**。其余章节是进阶说明。

> **DSA 版 vs swconfig 版怎么选？** 两个版本功能对等、都能正常上网；DSA 版用主线标准框架，每个网口是独立网卡（便于按口做策略 / 统计 / 桥接），swconfig 版沿用传统交换机配置、生态更成熟。想要“标准、可维护、按口管理”选本版；想要“久经验证、省心”选 [swconfig 版](https://github.com/iiibeloved/istoreos-hybrid-g68)。

---

## 目录

- [一、这是什么](#一这是什么)
- [二、固件特点](#二固件特点)
- [三、包含内容](#三包含内容)
- [四、刷机前注意事项](#四刷机前注意事项)
- [五、刷机方法](#五刷机方法)
- [六、刷机后注意事项](#六刷机后注意事项)
- [七、下载与校验](#七下载与校验)
- [八、已知限制](#八已知限制)
- [九、常见问题](#九常见问题)
- [十、技术实现（进阶）](#十技术实现进阶)
- [十一、本地构建](#十一本地构建)
- [致谢](#致谢)

---

## 一、这是什么

本固件面向 **RK3568 架构的 G68-PLUS 软路由 / NAS 小板**，把三套经过验证的成果合在一起：

| 组成 | 来源 | 带来的好处 |
| --- | --- | --- |
| **系统基座** | [iStoreOS 24.10 官方](https://github.com/istoreos/istoreos)（`istoreos-24.10`） | 内核 6.6、官方软件源、完整应用生态，随上游持续更新 |
| **设备适配层** | NSY G68 真机验证的 DTS / u-boot / 分区 / 按键配置 | 长按 Reset 进 MaskROM、5 口千兆、eMMC 分区布局 |
| **网络方案** | RTL8367S + 主线 **rtl8365mb DSA 驱动** | 5 口呈现为独立网卡 `lan1`~`lan4` / `wan`，无需私有 swconfig |

它**不是裁剪版**：iStoreOS 商店、Docker、文件共享、下载工具等一应俱全。设备适配以“整文件 overlay”方式注入，不在 iStoreOS 上游维护长期分叉，因此上游升级时冲突面最小。

网络部分采用 **Linux 主线 DSA**（`rtl8365mb`，已原生支持 RTL8367S），不使用 swconfig，也没有整文件覆盖驱动；配套的 SGMII MAC 选择修复以内核补丁形式提供。

---

## 二、固件特点

- **刷机省心：长按 Reset 就能进 MaskROM。** 上电时按住 Reset 键即可被 RKDevTool 识别，无需拆机短接测试点；刷写方式与 immortalwrt 固件一致（USB 双公头 + RKDevTool + 强制按地址写）。
- **标准 DSA 网络，5 口独立网卡。** `lan1`~`lan4` / `wan` 各自是独立网口，可分别配置、统计与桥接，语义清晰、便于管理与扩展；4 个 LAN 口默认同属 `br-lan`。
- **开箱就能上网。** LAN 口 DHCP 服务端、WAN 口 DHCP 客户端默认可用，插上网线即可获取地址。
- **完整 iStoreOS 生态。** 商店、初始化向导、Docker、SMB 共享（`samba4` / `ksmbd`）、WebDAV（`unishare` / `webdav2`）、NFS、文件管理 / 传输、定时控制、上网行为管理等应用全部内置，不是精简固件。
- **稳定可升级、可重复构建。** 每次构建以 iStoreOS 官方包清单为基准去重：同名 / 同文件的第三方包一律让位；滚动 feed 锁定到已验证提交、同名包生效来源统一指定、编译前做全包依赖版本校验，防止上游静默漂移导致“这次能编、下次编不过”；商店与 quickstart 始终跟随上游，不固化在仓库里。
- **完整生态含 Go 应用。** AList（网盘聚合）、DDNS-Go、Lucky 等要求较新 Go 版本的应用已随固件编译提供；构建侧通过 `GOTOOLCHAIN=auto` 与单线程重试兜底消除工具链竞态（见「技术实现」）。
- **多重自动化守卫。** 构建前做静态自检与硬件级交叉审核（DTS ↔ 内核配置 ↔ 包集），并对 u-boot 做源码 / 应用后 / 编译产物三层断言，防止 MaskROM 与网络能力被上游改动悄悄破坏。

---

## 三、包含内容

### 3.1 主要软件

| 类别 | 代表组件 |
| --- | --- |
| 商店 / 向导 | `luci-app-store`（iStore 商城）、`luci-app-quickstart`（初始化向导）、`luci-app-netwizard`（网络向导） |
| 容器 | `dockerd`、`containerd`、`runc`、`luci-app-dockerman` |
| 文件共享 | `samba4-server` + `luci-app-samba4`、`ksmbd-server` + `luci-app-ksmbd`（SMB）、`unishare`、`webdav2`、`nfs-kernel-server` |
| 网盘 / 下载 | `luci-app-alist`（AList 网盘聚合，含中文）、`lucky` + `luci-app-lucky`、`luci-app-fileassistant`、`luci-app-filemanager`、`luci-app-filebrowser`、`luci-app-filetransfer` |
| 网络 / DNS | `dnsmasq-full`（DNS + DHCP）、`firewall4`、`netifd`、`luci-app-openclash` / `luci-app-passwall` / `luci-app-homeproxy`、DSA 驱动栈 |
| 系统 / 管控 | `luci-app-diskman` + `smartmontools`（磁盘健康）、`luci-app-timecontrol`、`luci-app-control-webrestriction`、`luci-app-control-weburl`、`luci-app-wolplus`、`luci-app-argon-config` |
| 其他 | `luci-app-ddns-go`、内网穿透等 iStoreOS 生态应用 |

> SMB 共享出厂默认启用 `samba4`、不自启 `ksmbd`（两者都监听 TCP 445，同时自启会争用端口），详见[刷机后注意事项](#六刷机后注意事项)。
>
> 完整且权威的清单是每次 Release 附件中的 **`packages.manifest`**（含依赖展开，数量随每次构建与上游变化）。本表只列代表组件：配置文件直接选中约 **740** 项，依赖展开后更多；一律以该 manifest 为准。

### 3.2 网口与网络

| 逻辑接口 | 硬件端口 | 角色 |
| --- | --- | --- |
| `lan1` ~ `lan4` | RTL8367S port 0~3 | 4 个 LAN 口，默认同属 `br-lan`，DHCP 服务端 |
| `wan` | RTL8367S port 4 | 1 个 WAN 口，DHCP 客户端（可改 PPPoE） |
| CPU 上联 | `port@7` → `gmac0`（RGMII fixed-link 1000 Mb/s） | 5 口共用的 CPU 上行 |

- 5 个网口全部可用，交换机内部互访不受 CPU 上行带宽限制。
- 逻辑口为 DSA 标准命名 `lan1`~`lan4` / `wan`；物理口与逻辑口的对应以刷机后实测为准（见 [刷机后注意事项](#六刷机后注意事项)）。
- 面板上的 2.5G 标识口实际按 SGMII **1000 Mb/s** fixed-link 工作（真机实测），不是 2500 Mb/s。
- LAN/WAN 接口 MAC 由板级脚本按 eMMC CID 生成并覆盖，多次刷机后 MAC 保持稳定。

### 3.3 分区布局

| 分区 | 大小 | 用途 |
| --- | --- | --- |
| `uboot` | 16 MiB | u-boot / SPL |
| `kernel` | 16 MiB | 内核 + DTB（FIT 镜像） |
| `rootfs` | 500 MiB | 只读 squashfs 系统 |
| `rootfs_data` | 4096 MiB | 可写 overlay（配置、iStore / opkg、Docker 数据） |

> 升级镜像约 **100 MiB**（squashfs 压缩后）；`rootfs_data` 文件系统在首次启动时自动创建。

---

## 四、刷机前注意事项

1. **准备工具**：双公头 USB 数据线、`RKDevTool_Release_v3.18`、驱动 `Rockchip_DriverAssitant_v5.12`，以及**解压成 `.img` 的固件**（刷机工具不认 `.img.gz`）。
2. **核对文件**：下载后用 `sha256sum -c sha256sums` 校验镜像，不一致请重新下载。
3. **备份配置**：旧系统还能进入时，先在 LuCI「系统 → 备份/升级」导出配置备份。
4. **接对 USB 口**：用靠近网口一侧的 **USB OTG 口**连接电脑。
5. **保证供电**：刷写与首次启动期间**不要断电**，eMMC 写入中断最难恢复。
6. **理清网口角色**：本固件是 **4 LAN（`lan1`~`lan4`）+ 1 WAN（`wan`）**；刷机后需按实测确认哪个物理口是 `wan`，再把上级路由 / 光猫接到该口（见第六节）。
7. **管理地址预期**：默认网关为 **`192.168.100.1`**（iStoreOS 基座默认，已真机验证；若与局域网冲突，以电脑实际获取到的默认网关为准，首次向导中可修改）。

---

## 五、刷机方法

系统能否进入，选择对应方式：

### 5.1 系统还能进 → 在线升级

```
LuCI → 系统 → 备份/升级 → 上传 .img.gz → 勾选「保留配置」（如需清空则不勾）→ 执行
```

### 5.2 首次刷写 / 进不去系统 → MaskROM（USB 刷机）

1. 电脑安装驱动 `Rockchip_DriverAssitant_v5.12`，打开 `RKDevTool_Release_v3.18`。
2. 设备**断电**，双公头 USB 线连接电脑与设备 OTG 口。
3. **按住 Reset 键不松开 → 接通电源 → 待 RKDevTool 提示“发现一个 MaskROM 设备”后松开 Reset。**
   - 若长按无效，可用拆机短接测试点的传统方式兜底（loader 相同）。
4. 「高级功能」→ 加载 `rk356x_spl_loader_v1.21.113.bin`。
5. 「获取当前存储」→「**擦除所有**」，进度到 100% 才算成功（若“秒擦除”，需检查 eMMC）。
6. 「下载镜像」→ 选择**解压后的 `.img`** → **勾选「强制按地址写」** → 点击「执行」，等到 100% 成功。
7. 完成后断开 USB、重新上电，接好网线。

> **“强制按地址写”必须勾选**，否则可能写入不完整或校验失败。

---

## 六、刷机后注意事项

> 本节是新旧版本差异最容易被忽略的地方，请按序号操作。

1. **耐心等待首次启动（约 1~3 分钟）。** 首次开机会创建 `rootfs_data` 文件系统并执行初始化脚本，期间网口灯可能闪烁、页面暂时打不开，属正常现象；**不要在此阶段断电或反复重启**。
2. **进入初始化向导。** 浏览器访问默认网关（通常 **`http://192.168.100.1`**，或在电脑命令行执行 `ipconfig` / `route -n` 查看默认网关）→ 按 iStoreOS 向导完成设置，并**第一时间修改 root 密码**。
3. **确认网口识别正常。** SSH / TTYD 登录后执行 `ip -br link`，应能看到 `lan1`、`lan2`、`lan3`、`lan4`、`wan` 五个网卡——**看到这五个独立网卡，说明 DSA 驱动与网口初始化已正常工作**（旧版“只能当交换机、拿不到 IP”的问题即出在此环节，新固件已修复）。
4. **先确认 LAN，再接 WAN。**
   - 电脑接任意 LAN 口（`lan1`~`lan4`），应能自动获取 `192.168.100.x` 地址并打开管理页。
   - 再把上级路由 / 光猫的网线接到 **`wan` 口**，`wan` 默认 DHCP 获取地址；如需 PPPoE，在网络 / 向导中改为拨号并填入账号密码。
5. **核对物理口与逻辑口对应。** 逐一插拔网线，观察 `ip -br link` 中哪个 `lanX` / `wan` 的 `UP` 状态随之变化，据此确认物理口对应关系；`lan1`~`lan4` 应同属 `br-lan`，`wan` 不应在 `br-lan` 中。
6. **验证外网与软件源。** 执行 `ping -c3 223.5.5.5 && opkg update`，全通即表示网络与软件源正常。
7. **验证 MaskROM 能力（可选）。** 下次需要刷机时，用第五节的长按 Reset 流程验证一次即可；平时不必反复进 MaskROM。
8. **完成配置后备份。** 系统 → 备份/升级 → 生成配置备份并妥善保存，便于日后恢复。
9. **SMB 服务默认已配好，开箱即用。** 固件内置 `samba4-server` 与 `ksmbd-server` 两套 SMB 服务端，二者都监听 TCP **445** 端口，同时自启会争用端口。已通过首次启动脚本默认**启用 samba4、禁用 ksmbd 自启**，无需手动干预即可使用 SMB 共享。若确需改用 ksmbd：在「系统 → 启动项」中禁用 `samba4`、启用 `ksmbd` 并重启即可，SMB 文件共享功能本身不受影响。
10. **常见误区**：
   - 只接了 LAN 口、没接 WAN → 能进管理页但上不了外网，属正常，接好 WAN 即可。
   - 上级路由 LAN 口与本机 LAN 同为 `192.168.100.x` → 地址冲突，先在向导里把本机 LAN 改到其它网段。
   - `ip -br link` 里没有 `lan1`~`lan4` / `wan` → 所用镜像可能缺少 DSA 驱动，请核对 Release 的 `packages.manifest` 是否含 `kmod-dsa` / `kmod-dsa-realtek` / `kmod-dsa-rtl8366mb`。
   - 面板 2.5G 标识口按 1000 Mb/s 工作 → 规格如此，不是故障。

---

## 七、下载与校验

- **最新 Release**：<https://github.com/iiibeloved/istoreos-hybrid-g68-dsa/releases/latest>
- 版本号、镜像与校验值**以 Release 页面为准**（本仓库会持续更新，本文不写死版本号与哈希，避免过期）。

| 资产 | 说明 |
| --- | --- |
| `istoreos-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz` | 固件镜像（约 100 MiB，刷机前需解压） |
| `sha256sums` | 镜像校验值 |
| `packages.manifest` | 本次构建完整包清单（含依赖展开，以 Release 附件为准） |

**国内加速**（把 `<tag>` 和 `<file>` 替换为实际版本号与文件名，`https://` 后拼接以下前缀）：

- `https://gh-proxy.com/https://github.com/iiibeloved/istoreos-hybrid-g68-dsa/releases/download/<tag>/<file>`
- `https://ghfast.top/https://github.com/iiibeloved/istoreos-hybrid-g68-dsa/releases/download/<tag>/<file>`
- `https://ghproxy.net/https://github.com/iiibeloved/istoreos-hybrid-g68-dsa/releases/download/<tag>/<file>`

---

## 八、已知限制

- **不使用 WiFi**：G68 的 MT7916 未启用（WiFi 栈整体不选），需要无线请另行方案。
- **DNS/DHCP 用 `dnsmasq-full`**：与 `dnsmasq` 互斥，二者只能选其一。
- **SSL 栈为 mbedtls**：不选 `luci-ssl-openssl`（会与基座 `libustream-mbedtls` 冲突）。
- **2.5G 口实为 1000 Mb/s**：SGMII fixed-link 真机实测值。
- **DSA 需真机验收**：`rtl8365mb` 对 RTL8367S 的识别、端口物理对应、实际链路速率建议实机逐项确认。

---

## 九、常见问题

| 现象 | 处理 |
| --- | --- |
| 刷机后只能当交换机、拿不到 IP、无 WAN | 确认所用镜像是带 DSA 驱动的新版（见 Release 的 `packages.manifest` 是否含 `kmod-dsa` / `kmod-dsa-realtek` / `kmod-dsa-rtl8366mb`）；旧版无这些驱动，需重刷新版 |
| `ip -br link` 看不到 `lan1`~`lan4` / `wan` | 镜像缺 DSA 驱动或设备树不匹配，重刷带 915 补丁与 DSA 驱动的新版 |
| 能进管理页但上不了外网 | 检查 `wan` 口是否接了上级路由 / 光猫；`wan` 是否为 DHCP；上级 LAN 是否与本机能正常连通 |
| 管理页打不开 | 用 `ipconfig` 查电脑默认网关再访问；或确认处于同网段；首次启动请等 1~3 分钟 |
| RKDevTool 找不到 MaskROM 设备 | 检查驱动、USB 线（须为数据线）与 OTG 口；长按 Reset 时序或改用短接触点法 |
| 刷机中途报错 / 校验失败 | 重新“擦除所有”后勾选“强制按地址写”再刷；核对 sha256 |
| 商城 / quickstart 无中文 | 商城与向导跟随上游，版本更新后自带；中文为条件投递 |

---

## 十、技术实现（进阶）

### 10.1 为什么叫“杂交”（Hybrid）

不在 iStoreOS 里维护长期分叉的内核 / 设备树；设备层以**整文件 overlay** 交付，上游升级时冲突面最小。

### 10.2 目标与不变量

1. **基座 = 上游 iStoreOS 官方**（`istoreos-24.10`），每次构建 clone 最新提交；`upstream-watch` / `check-upstream` 在上游变化时自动触发构建；
2. **网络 = 主线 DSA 方案**（RTL8367S 5 口：`lan1`~`lan4` + `wan`，CPU = `gmac0` RGMII）；
3. **长按 Reset → MaskROM**：u-boot overlay（`boot_mode.c` + ADC defconfig + 板级 dts）与三层守卫；
4. **包集 = 全量 + 上游优先去重**：每轮 `package-guard` 以上游 defconfig 为基准比对，重复项自动注释并回写；
5. **商城 / quickstart 跟随上游**：来自 store / packages / luci feeds，仓库内不固化、不做整文件覆盖；
6. **设备树与 MAC 保持参考配置原样**：DSA 驱动直接用主线 6.6 原生 `rtl8365mb`（已原生支持 RTL8367S），不整文件覆盖驱动；
7. **Feed 防漂移、只交付 squashfs**：滚动 feed 锁到已验证提交、同名包来源固定、依赖版本守卫通过；显式关闭 ext4 rootfs，仅发布 squashfs 镜像（见 10.3）。
8. **配置行尾 = LF**：`configs/g68-hybrid.config` 必须以 LF 存储，CRLF 会使 `grep -qx` 包集自检与 `make defconfig` 静默失效（见 10.3）；

### 10.3 关键机制

- **长按 Reset → MaskROM**：SPL 阶段读 SARADC 通道 0；按住 Reset 上电即写 BROM 下载标志并复位，RKDevTool 直接识别 MaskROM 设备。u-boot 以 overlay-only 覆盖 `src/`，并由三层断言（`download key pressed` / `adc_channel_single_shot` / `BOOT_MODE_REG=0xfdc20200`）守护。
- **DSA 驱动**：内核符号 `CONFIG_NET_DSA` / `NET_DSA_REALTEK` / `NET_DSA_REALTEK_RTL8365MB` / `NET_DSA_REALTEK_SMI` 与 tagger `CONFIG_NET_DSA_TAG_RTL4_A` 由 `device/kernel-config` 补齐；`915` 补丁修复 SGMII MAC 选择。
- **官方基准去重**：同名 / 同文件 / PROVIDES 冲突项以上游为准自动注释；`dnsmasq-full` 为本固件选定的 DNS/DHCP 实现（与 `dnsmasq` 互斥），`luci-ssl-openssl` / `libustream-openssl` 让位基座 mbedtls 变体。
- **Feed 防漂移（fail-fast）**：滚动 feed 锁到已验证提交（`configs/feeds.lock`），同名包的生效来源统一声明（`configs/feed-precedence.txt`，如 `sing-box` 固定取 `small`）；构建时用 `feed-pin.sh` 固定提交、`feed-sources.sh` 删除其他 feed 的同名链接并重装校验，`dep-guard.sh` 在 `make defconfig` 后遍历所有选中包的版本化依赖做秒级校验。上游 packages 的旧版 `sing-box` 抢占链接、HomeProxy 要求 `>=1.15.0_alpha10` 导致“编译 3 小时后才失败”的问题因此被提前拦截。
- **只交付 squashfs**：`configs/g68-hybrid.config` 显式关闭 `CONFIG_TARGET_ROOTFS_EXT4FS`、保留 `CONFIG_TARGET_ROOTFS_SQUASHFS=y`，并在 `make defconfig` 后二次压回校验；收集产物时拒绝任何 `*-ext4*.img.gz`。ext4 不压缩（未压缩 rootfs 树约 691 MiB，塞不进 500 MiB 分区），squashfs 压缩后约 100 MiB，故只发布 squashfs 镜像。
- **Go 工具链放宽**：`alist` / `ddns-go` / `xray` / `sing-box` 等 small feed 的 Go 包要求 Go >= 1.25（早期失败日志：`go: go.mod requires go >= 1.25.0 (running go 1.23.12)`）。`build.yml` 把 `feeds/packages/lang/golang/` 内的 `GOTOOLCHAIN=local` 统一替换为 `auto`，让各包自动获取匹配工具链，并保留「并行编译失败 → `-j1 V=s` 单线程重试」兜底，规避多包并发下载工具链的竞态。AList 曾因此被临时移除，现已恢复并随固件提供。
- **配置行尾固定为 LF**：`configs/g68-hybrid.config` 必须以 LF 行尾存储。`selftest.sh` 用 `grep -qx` 对 `CONFIG_PACKAGE_xxx=y` 做整行精确匹配，`make defconfig` 也按 LF 解析；若被写成 CRLF，行尾的 `\r` 会让包集自检全项误报、defconfig 静默丢符号。注意：通过 Git Data API 直接创建 blob 会绕过 git 客户端的行尾规范化，提交前务必核对远程 blob 的真实行尾。
- **多重自动化守卫**：`selftest.sh`（含补丁白名单 910/911/913/915 与 tagger 断言）、`hw-audit.sh`、`verify-maskrom.sh`、`package-guard`。

### 10.4 构建流水线

```text
iStoreOS 官方源 (istoreos-24.10)
   │ clone
   ▼
apply-device.sh ──► 设备层注入（DTS / u-boot overlay / 内核补丁含 915 / 分区 / i18n）
   ▼
selftest.sh ──► 静态自检（overlay / defconfig / 补丁 / DTS / 镜像定义）
   ▼
hw-audit.sh ──► 硬件级审核（DTS ↔ kernel-config ↔ 包集 ↔ u-boot defconfig）
   ▼
package-guard ──► 以官方清单为基准去重（同名 / 同文件 / PROVIDES）
   ▼
uboot-check ──► feed-pin 固定提交 → 只编译 u-boot + 三层产物断言
   ▼
build ──► feed-pin 锁定滚动 feed → feed-sources 固定同名包来源
          → defconfig → 关闭 ext4 / 保留 squashfs → dep-guard 依赖版本守卫
          → 全量编译 → 仅收集 squashfs 镜像 → 分区表校验
          → artifact → Release → 回写 state 锁
```

| 作业 | 职责 |
| --- | --- |
| `check-upstream` | 对比上游 commit 与 `state` 锁，决定是否构建 |
| `prepare` | 应用设备层、静态自检、硬件审核、官方基准去重 |
| `uboot-check` | `feed-pin` 固定提交后独立编译 u-boot，验证 MaskROM 链路 |
| `build` | 固定 feed 提交与同名包来源、defconfig 归一化（关闭 ext4）、依赖版本守卫、全量编译、仅接受 squashfs 镜像并校验、发布 Release、回写 `upstream.lock` |

触发方式：`push`（配置变更）、`workflow_dispatch`（手动）、`schedule`（每周检查）、`upstream-watch`（上游变化自动触发）。

### 10.5 仓库结构

```text
device/
  kernel-dts/            G68 内核设备树（SGMII/XPCS、DSA switch@29、adc-keys、eMMC）
  kernel-config          内核配置片段（Realtek DSA / tagger 等）
  board.d/               板级网络映射 02_network_g68（DSA 端口命名，不改上游）
  kernel-patches/        910/911/913/914/915 内核补丁（915 为 SGMII MAC 选择修复）
  uboot/                 u-boot overlay（boot_mode、defconfig、板级 dts、版本守卫）
  i18n-overlay/          中文覆盖（条件投递）
  hw-exemptions.txt      硬件豁免清单（如 WiFi）
scripts/                 apply / selftest / hw-audit / verify-maskrom / package-guard 等
  feed-pin.sh            按 feeds.lock 固定滚动 feed 提交（防 main 漂移）
  feed-sources.sh        按 feed-precedence.txt 固定同名包的生效来源
  dep-guard.sh           defconfig 后全包依赖版本一致性守卫（fail-fast）
configs/
  g68-hybrid.config      完整包配置（含目标 / 设备 / 分区，显式关闭 ext4 rootfs）
  feeds.lock            滚动 feed 的已验证提交
  feed-precedence.txt   同名包生效来源优先级
.github/workflows/       build / maskrom-guard / package-guard / upstream-watch
```

---

## 十一、本地构建

```sh
git clone --depth 1 -b istoreos-24.10 https://github.com/istoreos/istoreos.git
sh scripts/apply-device.sh istoreos          # 注入设备层
sh scripts/selftest.sh istoreos              # 静态自检
sh scripts/hw-audit.sh                       # 硬件审核
cd istoreos
./scripts/feeds update -a
sh ../scripts/feed-pin.sh . ../configs/feeds.lock            # 固定滚动 feed
./scripts/feeds install -a
sh ../scripts/feed-sources.sh . ../configs/feed-precedence.txt # 固定同名包来源
# 该配置必须为 LF 行尾：CRLF 会让 grep -qx 自检与 make defconfig 静默失效
cp ../configs/g68-hybrid.config .config
make defconfig
# defconfig 会把 EXT4FS 拉回 y，必须二次压回（自动构建已内置此步）
sed -i -E 's/^CONFIG_TARGET_ROOTFS_EXT4FS=y$/# CONFIG_TARGET_ROOTFS_EXT4FS is not set/' .config
sh ../scripts/dep-guard.sh . ../configs/feed-precedence.txt  # 依赖版本守卫
make -j"$(nproc)"
```

产物：`istoreos/bin/targets/rockchip/armv8/*nsy_g68-plus*sysupgrade.img.gz`

---

## 致谢

- [iStoreOS](https://github.com/istoreos/istoreos) —— 系统基座与软件生态
- [immortalwrt](https://github.com/immortalwrt/immortalwrt) —— 设备层参考与真机验证经验
- Linux 主线 DSA / `rtl8365mb` 驱动维护者
- 所有上游包维护者

> 本项目仅做设备层移植与 CI 编排，固件内容遵循各上游组件许可证。
