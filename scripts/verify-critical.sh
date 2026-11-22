#!/bin/sh
# =============================================================================
#  核心网络功能包守卫（defconfig 后 + 最终 manifest，双阶段 fail-fast）
#
#  DSA 方案说明（与 swconfig 版 hybrid 不同）：
#    G68 的 RTL8367S 走 Realtek DSA 驱动，驱动是**内核内建符号**
#    （CONFIG_NET_DSA_REALTEK_RTL8365MB / TAG_RTL4_A 等，由 device/kernel-config
#    注入 config-6.6，selftest 第 6 节 + hw-audit H3 在源码层守护）。
#    因此 opkg manifest 里没有 kmod-dsa-* 包可断言；本脚本守的是用户态网络生命线：
#      dnsmasq-full  LAN DHCP/DNS 服务端（与 dnsmasq 互斥）
#      firewall4     firewall4 防火墙（上游 builtin）
#      netifd        网络守护进程（上游 builtin）
#
#  为什么需要两阶段：
#    selftest.sh / hw-audit.sh 只检查 configs/g68-hybrid.config 这个"输入"，
#    真正的包集由 make defconfig 展开、由最终 manifest 落地。上游 feed 漂移可能
#    让 dnsmasq-full 等关键包被静默丢弃，导致构建"成功"但刷机后 LAN 拿不到 IP。
#    因此：
#      config   <.config>       build 作业 make defconfig 之后立即断言，
#                                缺关键包则秒级失败，不浪费数小时编译；
#      manifest <manifest文件>  编译产物阶段再断言一次，确保最终镜像确实含包，
#                                缺任一包则禁止发布 Release。
#
#  用法：verify-critical.sh config <.config> | verify-critical.sh manifest <manifest>
# =============================================================================
set -eu
MODE="${1:?用法: verify-critical.sh config|manifest <文件>}"
FILE="${2:?用法: verify-critical.sh config|manifest <文件>}"
[ -f "$FILE" ] || { echo "::error::关键包守卫: 文件不存在 $FILE"; exit 1; }

# config 阶段只断言显式选择的包符号（上游 builtin 的 firewall4/netifd 不在 config 里显式列）
case "$MODE" in
	config)   CRIT="dnsmasq-full" ;;
	manifest) CRIT="dnsmasq-full firewall4 netifd" ;;
	*) echo "::error::未知模式 $MODE（应为 config 或 manifest）" >&2; exit 2 ;;
esac

FAIL=0
ok()  { printf '  [OK]   %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*"; FAIL=$((FAIL+1)); }

echo "== [guard] 核心网络功能包（$MODE: $FILE）=="
for p in $CRIT; do
	case "$MODE" in
		config)   pat="^CONFIG_PACKAGE_${p}=y$" ;;
		manifest) pat="^${p} - " ;;
	esac
	if grep -qE "$pat" "$FILE"; then
		ok "$p"
	else
		bad "缺关键包 $p（LAN/WAN/DHCP 将不可用，禁止继续）"
	fi
done

if [ "$MODE" = "config" ]; then
	if grep -qE '^CONFIG_PACKAGE_dnsmasq=y$' "$FILE"; then
		bad "dnsmasq 与 dnsmasq-full 同时选中（PROVIDES 同名，必须互斥）"
	else
		ok "dnsmasq 未与 dnsmasq-full 冲突"
	fi
fi

echo
if [ "$FAIL" -gt 0 ]; then
	echo "::error::核心网络包守卫失败：$FAIL 项 —— 禁止继续构建/发布"
	exit 1
fi
echo "核心网络包守卫通过 ✅（LAN/WAN/DHCP 生命线齐全）"
