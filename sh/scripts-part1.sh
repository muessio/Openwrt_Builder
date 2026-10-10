#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: scripts-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

echo "--- DIY Part 1 脚本开始执行 ---"
echo "WORKFLOW_NAME: $WORKFLOW_NAME"
echo "TAG2: $TAG2"
echo "------------------------------------------"

set_default_ip() {
    local ip="$1"
    local label="$2"
    sed -i "s/192.168.1.1/$ip/g" package/base-files/files/bin/config_generate
    echo "$label IP 修改为 $ip"
}

if [[ "$WORKFLOW_NAME" == "AXT-1800" || "$WORKFLOW_NAME" == "JDC-AX6600" ]]; then
    if [[ "$WORKFLOW_NAME" == "AXT-1800" ]]; then
        set_default_ip "192.168.8.1" "AXT-1800"
    elif [[ "$WORKFLOW_NAME" == "JDC-AX6600" ]]; then
        set_default_ip "192.168.100.1" "JDC-AX6600"
    fi
    wget -q https://raw.githubusercontent.com/m0eak/openwrt_patch/refs/heads/main/gl-axt1800/9999-gl-axt1800-dts-change-cooling-level.patch -O target/linux/qualcommax/patches-6.12/9999-gl-axt1800-dts-change-cooling-level.patch || true
    rm -f package/kernel/mac80211/patches/nss/ath11k/999-902-ath11k-fix-WDS-by-disabling-nwds.patch
    rm -f package/kernel/mac80211/patches/nss/subsys/999-775-wifi-mac80211-Changes-for-WDS-MLD.patch

elif [[ "$WORKFLOW_NAME" == "x86_immortalwrt" ]]; then
    VERSION2=${TAG2#v}
    set_default_ip "192.168.100.1" "x86"
    if [ -n "$VERSION2" ]; then
        sed -i "s/replace/$VERSION2/g" files/etc/uci-defaults/zzz_m0eak 2>/dev/null || true
    fi

elif [[ "$WORKFLOW_NAME" == "GL-MT3600BE" ]]; then
    CUSTOM_DTS_URL="https://raw.githubusercontent.com/openwrt/openwrt/cced8d95f3caa9f48eaeb4ef2d15426d20afaf16/target/linux/mediatek/dts/mt7987a-glinet-gl-mt3600be.dts"
    CUSTOM_DTS_TARGET="target/linux/mediatek/dts/mt7987a-glinet-gl-mt3600be.dts"
    curl -fL "$CUSTOM_DTS_URL" -o "$CUSTOM_DTS_TARGET" 2>/dev/null || true
    set_default_ip "192.168.9.1" "mt3600be"

elif [[ "$WORKFLOW_NAME" == "gl-mt5000_immortalwrt" || "$WORKFLOW_NAME" == "GL-MT5000" ]]; then
    echo ">>> 检测到设备: $WORKFLOW_NAME。导入 GL-MT5000 支持与 Realtek RTL8366 驱动 <<<"

    GL_TMP_DIR="/tmp/glinet_mt5000_source"
    rm -rf "$GL_TMP_DIR"
    git clone --depth 1 -b mt5000 https://github.com/GLiNet-Tech/openwrt.git "$GL_TMP_DIR"

    if [[ -d "$GL_TMP_DIR" ]]; then
        # 1. DTS-Dateien importieren
        mkdir -p target/linux/mediatek/dts target/linux/mediatek/files/arch/arm64/boot/dts/mediatek
        cp -f "$GL_TMP_DIR"/target/linux/mediatek/dts/*gl-mt5000* target/linux/mediatek/dts/ 2>/dev/null || true
        cp -f "$GL_TMP_DIR"/target/linux/mediatek/files/arch/arm64/boot/dts/mediatek/*gl-mt5000* target/linux/mediatek/files/arch/arm64/boot/dts/mediatek/ 2>/dev/null || true

        # 2. Base-Files und Board-Erkennung (02_network) importieren
        mkdir -p target/linux/mediatek/filogic/base-files
        cp -rf "$GL_TMP_DIR"/target/linux/mediatek/filogic/base-files/* target/linux/mediatek/filogic/base-files/ 2>/dev/null || true

        # 3. Gerätedefinition in filogic.mk einbinden
        if ! grep -q "glinet_gl-mt5000" target/linux/mediatek/image/filogic.mk 2>/dev/null; then
            for mk in "$GL_TMP_DIR"/target/linux/mediatek/image/*.mk; do
                if grep -q "glinet_gl-mt5000" "$mk" 2>/dev/null; then
                    sed -n '/define Device\/glinet_gl-mt5000/,/endef/p' "$mk" >> target/linux/mediatek/image/filogic.mk
                    echo '$(eval $(call BuildImage,glinet_gl-mt5000))' >> target/linux/mediatek/image/filogic.mk
                    echo 'TARGET_DEVICES += glinet_gl-mt5000' >> target/linux/mediatek/image/filogic.mk
                    break
                fi
            done
        fi

        # 4. Kernel-Patches für Realtek RTL8366 versionsunabhängig übertragen
        GL_PATCH_DIR=$(find "$GL_TMP_DIR"/target/linux/mediatek/ -maxdepth 1 -type d -name "patches-*" | head -n 1)

        if [ -n "$GL_PATCH_DIR" ] && [ -d "$GL_PATCH_DIR" ]; then
            for pdir in target/linux/mediatek/patches-*; do
                if [ -d "$pdir" ]; then
                    echo "Kopiere Realtek-Patches aus $GL_PATCH_DIR nach $pdir"
                    cp -f "$GL_PATCH_DIR"/*rtl8366* "$pdir"/ 2>/dev/null || true
                    cp -f "$GL_PATCH_DIR"/*realtek* "$pdir"/ 2>/dev/null || true
                fi
            done
        fi

        # 4b. Treiber-Quellen direkt spiegeln
        mkdir -p target/linux/mediatek/files/drivers/net/dsa/realtek
        find "$GL_TMP_DIR" -type f \( -name "*rtl8366*" -o -name "*realtek*" \) -path "*/drivers/net/dsa/*" -exec cp -f {} target/linux/mediatek/files/drivers/net/dsa/realtek/ \; 2>/dev/null || true

        # 5. Kernel-Konfiguration anpassen und Kconfig-Prompts neutralisieren
        for cfg in target/linux/mediatek/filogic/config-* target/linux/mediatek/config-*; do
            if [ -f "$cfg" ]; then
                sed -i '/CONFIG_NET_DSA/d' "$cfg"
                sed -i '/CONFIG_FIXED_PHY/d' "$cfg"
                cat << 'EOF' >> "$cfg"
CONFIG_NET_DSA=y
CONFIG_NET_DSA_TAG_RTL4_A=y
CONFIG_NET_DSA_TAG_NONE=y
CONFIG_NET_DSA_REALTEK=y
CONFIG_NET_DSA_REALTEK_RTL8366RB=y
CONFIG_NET_DSA_REALTEK_RTL8366UB=y
CONFIG_NET_DSA_REALTEK_SMI=y
CONFIG_NET_DSA_REALTEK_MDIO=y
CONFIG_FIXED_PHY=y
CONFIG_USB_NET_DRIVERS=y
CONFIG_USB_RTL8152=y
CONFIG_USB_NET_CDC_NCM=y
CONFIG_NET_DSA_AN8855=n
CONFIG_NET_DSA_BCM_SF2=n
CONFIG_NET_DSA_LOOP=n
CONFIG_NET_DSA_HIRSCHMANN_HELLCREEK=n
CONFIG_NET_DSA_MICROCHIP_KSZ9477=n
CONFIG_NET_DSA_MICROCHIP_KSZ8795=n
CONFIG_NET_DSA_MV88E6060=n
CONFIG_NET_DSA_MV88E6XXX=n
CONFIG_NET_DSA_AR9331=n
CONFIG_NET_DSA_SJA1105=n
CONFIG_NET_DSA_XRS700X=n
CONFIG_NET_DSA_QCA8K=n
CONFIG_NET_DSA_REALTEK_RTL8365MB=n
CONFIG_NET_DSA_SMSC_LAN9303=n
CONFIG_NET_DSA_VITESSE_VSC73XX=n
EOF
            fi
        done

        rm -rf "$GL_TMP_DIR"
    fi

    # Footstrap Theme Feed hinzufügen
    if ! grep -q "luci-theme-footstrap" feeds.conf.default 2>/dev/null; then
        echo "src-git footstrap https://github.com/VizzleTF/luci-theme-footstrap.git" >> "feeds.conf.default"
    fi

    set_default_ip "192.168.100.1" "mt5000-immortalwrt"
fi

echo "--- DIY Part 1 脚本执行完毕 ---"
