#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Dateiname: scripts-part2.sh
# Beschreibung: OpenWrt DIY Skript Teil 2 (wird nach dem Aktualisieren der Feeds ausgeführt)
#

TARGET_DIR="${PWD}/package/custom"

declare -A REPOS=(
    ["https://github.com/sbwml/luci-app-mosdns"]=""
    ["https://github.com/chenmozhijin/turboacc"]=""
    ["https://github.com/gdy666/luci-app-lucky"]=""
    ["https://github.com/m0eak/fancontrol"]=""
    ["https://github.com/animegasan/luci-app-wolplus"]=""
    ["https://github.com/0x676e67/luci-theme-design"]="js"
    ["https://github.com/0x676e67/luci-app-design-config.git"]=""
    ["https://github.com/nikkinikki-org/OpenWrt-nikki"]=""
    ["https://github.com/sirpdboy/luci-app-partexp"]=""
    ["https://github.com/pymumu/luci-app-smartdns"]=""
    ["https://github.com/pymumu/smartdns"]=""
    ["https://github.com/sbwml/v2ray-geodata"]=""
    ["https://github.com/vernesong/OpenClash.git"]=""
    ["https://github.com/eamonxg/luci-theme-aurora"]=""
    ["https://github.com/eamonxg/luci-theme-shadcn.git"]=""
    ["https://github.com/eamonxg/luci-app-aurora-config"]=""
    ["https://github.com/NONGFAH/luci-app-athena-led.git"]=""
    ["https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community.git"]=""
    ["https://github.com/m0eak/openwrt-gecoosac.git"]=""
    ["https://github.com/miaoermua/luci-app-leigod-acc.git"]=""
    ["https://github.com/EasyTier/luci-app-easytier"]="v2.6.4"
    ["https://github.com/Openwrt-Passwall/openwrt-passwall2"]=""
    ["https://github.com/Openwrt-Passwall/openwrt-passwall"]=""
    ["https://github.com/Openwrt-Passwall/openwrt-passwall-packages"]=""
    ["https://github.com/10000ge10000/luci-app-openclaw"]=""
    ["https://github.com/Slava-Shchipunov/awg-openwrt"]=""
    ["https://github.com/QiuSimons/luci-app-daed"]=""
    ["https://github.com/sirpdboy/luci-app-ddns-go.git"]=""
    ["https://github.com/tty228/luci-app-wechatpush.git"]=""
    ["https://github.com/gaoderby/luci-app-kms.git"]=""
    ["https://github.com/sbwml/luci-app-ramfree.git"]=""
    ["https://github.com/lisaac/luci-app-diskman"]=""
)

CONFLICTING_MAKEFILE_KEYWORDS=(
    "mosdns"
    "openclash"
    "luci-app-lucky"
    "smartdns"
    "v2ray-geodata"
    "xray-core"
    "daed"
    "ddns-go"
)

patch_rust_makefile() {
    if [ -e "feeds/packages/lang/rust/Makefile" ]; then
        sed -i 's/--set=llvm\.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' feeds/packages/lang/rust/Makefile
    fi
}

reset_custom_package_dir() {
    [ -n "$TARGET_DIR" ] && [ "$TARGET_DIR" != "/" ] && rm -rf "$TARGET_DIR" && mkdir -p "$TARGET_DIR"
}

remove_conflicting_makefiles() {
    find . -type f -name "Makefile" ! -path "$TARGET_DIR/*" -print0 | while IFS= read -r -d $'\0' file; do
        file_lower="${file,,}"
        for keyword in "${CONFLICTING_MAKEFILE_KEYWORDS[@]}"; do
            if [[ "$file_lower" == *"$keyword"* ]]; then
                rm -f "$file"
                break
            fi
        done
    done
}

clone_repo() {
    local repo_url="$1"
    local repo_branch="${REPOS[$repo_url]}"
    local repo_name="$(basename -s .git "$repo_url")"
    local repo_dir="$TARGET_DIR/$repo_name"

    [ -d "$repo_dir" ] && return 0
    if [ -z "$repo_branch" ]; then
        git clone --single-branch --depth 1 "$repo_url" "$repo_dir"
    else
        git clone --single-branch --depth 1 -b "$repo_branch" "$repo_url" "$repo_dir"
    fi
}

clone_custom_repos() {
    for repo in "${!REPOS[@]}"; do
        clone_repo "$repo"
    done
}

echo "--- DIY Part 2: Skriptausführung gestartet ---"
echo "WORKFLOW_NAME: $WORKFLOW_NAME"

# 1. DEIN ORIGINALER WORKFLOW (Build filogic.yml / GL-MT5000) - 100% UNBERÜHRT
if [[ "$WORKFLOW_NAME" == "gl-mt5000_immortalwrt" || "$WORKFLOW_NAME" == "GL-MT5000" || "$WORKFLOW_NAME" =~ "GL-MT5000" ]]; then
    echo ">>> Konfiguriere GL-MT5000 (ImmortalWrt) Board- und Treibereinstellungen <<<"

    # 1. 02_network patchen
    NETWORK_SETUP="target/linux/mediatek/filogic/base-files/etc/board.d/02_network"
    if [ -f "$NETWORK_SETUP" ]; then
        if ! grep -q "glinet,gl-mt5000" "$NETWORK_SETUP"; then
            sed -i '/glinet,gl-mt6000)/i \
glinet,gl-mt5000)\
\tucidef_set_interfaces_lan_wan "lan1 lan2" "eth1"\
\t;;' "$NETWORK_SETUP"
        fi
    fi

    # 2. Statische Fallback-Netzwerkkonfiguration in RootFS injizieren
    mkdir -p package/base-files/files/etc/config
    cat << 'EOF' > package/base-files/files/etc/config/network
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'lan1'
	list ports 'lan2'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '192.168.100.1'
	option netmask '255.255.255.0'

config interface 'wan'
	option device 'eth1'
	option proto 'static'
	option ipaddr '192.168.10.1'
	option netmask '255.255.255.0'
EOF

    # 3. Kernel- und Modulpakete für Realtek Switch, USB Mass Storage, Dateisysteme & Cake aktivieren
    cat << 'EOF' >> .config
# --- Switch / DSA Treiber ---
CONFIG_PACKAGE_kmod-dsa=y
CONFIG_PACKAGE_kmod-dsa-realtek=y
CONFIG_PACKAGE_kmod-dsa-rtl8366rb=y
CONFIG_PACKAGE_kmod-switch-rtl8366-smi=y
CONFIG_PACKAGE_kmod-dsa-tag-rtl4-a=y

# --- USB Storage & Block Devices ---
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb-storage-uas=y
CONFIG_PACKAGE_kmod-scsi-core=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_f2fs-tools=y
CONFIG_PACKAGE_dosfstools=y

# --- Dateisysteme ---
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-f2fs=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-nls-cp437=y
CONFIG_PACKAGE_kmod-nls-iso8859-1=y
CONFIG_PACKAGE_kmod-nls-utf8=y

# --- SQM QoS mit Cake ---
CONFIG_PACKAGE_sqm-scripts=y
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_kmod-sched-cake=y
CONFIG_PACKAGE_kmod-sched-core=y
CONFIG_PACKAGE_tc-tiny=y

# --- LuCI Theme ---
CONFIG_PACKAGE_luci-theme-footstrap=y
EOF

    # 4. WAN-Rescue Firewall-Regel hinterlegen
    mkdir -p package/base-files/files/etc/uci-defaults/
    cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-gl-mt5000-wan-rescue
uci -q batch << 'UCIBATCH'
set firewall.wan_rescue=rule
set firewall.wan_rescue.name='Allow-WAN-Access-Rescue'
set firewall.wan_rescue.src='wan'
set firewall.wan_rescue.proto='tcp'
set firewall.wan_rescue.dest_port='22 80 443'
set firewall.wan_rescue.target='ACCEPT'
commit firewall
UCIBATCH
exit 0
EOF
    chmod +x package/base-files/files/etc/uci-defaults/99-gl-mt5000-wan-rescue

    # 5. Standard-Theme auf Footstrap vorkonfigurieren
    cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-default-theme-footstrap
uci set luci.main.mediaurlbase='/luci-static/footstrap'
uci commit luci
exit 0
EOF
    chmod +x package/base-files/files/etc/uci-defaults/99-default-theme-footstrap

# 2. NEUER SEPARATER WORKFLOW: ImmortalWrt Brume 3 stable (25.12)
elif [[ "$WORKFLOW_NAME" == "Immortalwrt Brume 3 stable" ]]; then
    echo ">>> Konfiguriere Immortalwrt Brume 3 stable <<<"

    NETWORK_SETUP="target/linux/mediatek/filogic/base-files/etc/board.d/02_network"
    if [ -f "$NETWORK_SETUP" ]; then
        if ! grep -q "glinet,gl-mt5000" "$NETWORK_SETUP"; then
            sed -i '/glinet,gl-mt6000)/i \
glinet,gl-mt5000)\
\tucidef_set_interfaces_lan_wan "lan1 lan2" "eth1"\
\t;;' "$NETWORK_SETUP"
        fi
    fi

    mkdir -p package/base-files/files/etc/config
    cat << 'EOF' > package/base-files/files/etc/config/network
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'lan1'
	list ports 'lan2'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '192.168.100.1'
	option netmask '255.255.255.0'

config interface 'wan'
	option device 'eth1'
	option proto 'static'
	option ipaddr '192.168.10.1'
	option netmask '255.255.255.0'
EOF

    cat << 'EOF' >> .config
# --- Switch / DSA Treiber ---
CONFIG_PACKAGE_kmod-dsa=y
CONFIG_PACKAGE_kmod-dsa-realtek=y
CONFIG_PACKAGE_kmod-dsa-rtl8366rb=y
CONFIG_PACKAGE_kmod-switch-rtl8366-smi=y
CONFIG_PACKAGE_kmod-dsa-tag-rtl4-a=y

# --- USB Storage & Block Devices ---
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb-storage-uas=y
CONFIG_PACKAGE_kmod-scsi-core=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_f2fs-tools=y
CONFIG_PACKAGE_dosfstools=y

# --- Dateisysteme ---
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-f2fs=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-nls-cp437=y
CONFIG_PACKAGE_kmod-nls-iso8859-1=y
CONFIG_PACKAGE_kmod-nls-utf8=y

# --- SQM QoS mit Cake ---
CONFIG_PACKAGE_sqm-scripts=y
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_kmod-sched-cake=y
CONFIG_PACKAGE_kmod-sched-core=y
CONFIG_PACKAGE_tc-tiny=y

# --- LuCI Theme ---
CONFIG_PACKAGE_luci-theme-footstrap=y
EOF

    mkdir -p package/base-files/files/etc/uci-defaults/
    cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-gl-mt5000-wan-rescue
uci -q batch << 'UCIBATCH'
set firewall.wan_rescue=rule
set firewall.wan_rescue.name='Allow-WAN-Access-Rescue'
set firewall.wan_rescue.src='wan'
set firewall.wan_rescue.proto='tcp'
set firewall.wan_rescue.dest_port='22 80 443'
set firewall.wan_rescue.target='ACCEPT'
commit firewall
UCIBATCH
exit 0
EOF
    chmod +x package/base-files/files/etc/uci-defaults/99-gl-mt5000-wan-rescue

    cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-default-theme-footstrap
uci set luci.main.mediaurlbase='/luci-static/footstrap'
uci commit luci
exit 0
EOF
    chmod +x package/base-files/files/etc/uci-defaults/99-default-theme-footstrap

# 3. NEUER SEPARATER WORKFLOW: OpenWrt Brume 3 stable (25.12)
elif [[ "$WORKFLOW_NAME" == "OpenWrt Brume 3 stable" ]]; then
    echo ">>> Konfiguriere GL-MT5000 für offizielles OpenWrt 25.12 <<<"

    NETWORK_SETUP="target/linux/mediatek/filogic/base-files/etc/board.d/02_network"
    if [ -f "$NETWORK_SETUP" ]; then
        if ! grep -q "glinet,gl-mt5000" "$NETWORK_SETUP"; then
            sed -i '/glinet,gl-mt6000)/i \
glinet,gl-mt5000)\
\tucidef_set_interfaces_lan_wan "lan1 lan2" "eth1"\
\t;;' "$NETWORK_SETUP"
        fi
    fi

    mkdir -p package/base-files/files/etc/config
    cat << 'EOF' > package/base-files/files/etc/config/network
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'lan1'
	list ports 'lan2'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '192.168.100.1'
	option netmask '255.255.255.0'

config interface 'wan'
	option device 'eth1'
	option proto 'static'
	option ipaddr '192.168.10.1'
	option netmask '255.255.255.0'
EOF

    cat << 'EOF' >> .config
# --- Switch / DSA Treiber ---
CONFIG_PACKAGE_kmod-dsa=y
CONFIG_PACKAGE_kmod-dsa-realtek=y
CONFIG_PACKAGE_kmod-dsa-rtl8366rb=y
CONFIG_PACKAGE_kmod-switch-rtl8366-smi=y
CONFIG_PACKAGE_kmod-dsa-tag-rtl4-a=y

# --- USB Storage & Block Devices ---
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb-storage-uas=y
CONFIG_PACKAGE_kmod-scsi-core=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_f2fs-tools=y
CONFIG_PACKAGE_dosfstools=y

# --- Dateisysteme ---
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-f2fs=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-nls-cp437=y
CONFIG_PACKAGE_kmod-nls-iso8859-1=y
CONFIG_PACKAGE_kmod-nls-utf8=y

# --- SQM QoS mit Cake ---
CONFIG_PACKAGE_sqm-scripts=y
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_kmod-sched-cake=y
CONFIG_PACKAGE_kmod-sched-core=y
CONFIG_PACKAGE_tc-tiny=y
EOF

    mkdir -p package/base-files/files/etc/uci-defaults/
    cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-gl-mt5000-wan-rescue
uci -q batch << 'UCIBATCH'
set firewall.wan_rescue=rule
set firewall.wan_rescue.name='Allow-WAN-Access-Rescue'
set firewall.wan_rescue.src='wan'
set firewall.wan_rescue.proto='tcp'
set firewall.wan_rescue.dest_port='22 80 443'
set firewall.wan_rescue.target='ACCEPT'
commit firewall
UCIBATCH
exit 0
EOF
    chmod +x package/base-files/files/etc/uci-defaults/99-gl-mt5000-wan-rescue

else
    patch_rust_makefile
    reset_custom_package_dir
    remove_conflicting_makefiles
    clone_custom_repos
fi

echo "--- DIY Part 2: Skriptausführung beendet ---"
