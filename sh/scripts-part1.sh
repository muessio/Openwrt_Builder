#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: scripts-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# --- 调试信息：打印所有可能用到的环境变量 ---
echo "--- 脚本开始执行，正在检查环境变量 ---"
echo "WORKFLOW_NAME: $WORKFLOW_NAME" # 这是最重要的判断依据！
echo "TAG (from libwrt): $TAG"
echo "TAG2 (from immortalwrt): $TAG2"
echo "------------------------------------------"

set_default_ip() {
    local ip="$1"
    local label="$2"

    sed -i "s/192.168.1.1/$ip/g" package/base-files/files/bin/config_generate
    echo "$label IP 修改为 $ip"
}

# --- 根据 WORKFLOW_NAME 执行不同的逻辑 ---

# --- 逻辑块 1: 处理 AXT-1800 和 JDC-AX6600 ---
if [[ "$WORKFLOW_NAME" == "AXT-1800" || "$WORKFLOW_NAME" == "JDC-AX6600" ]]; then
    echo ">>> 检测到设备: $WORKFLOW_NAME。开始执行 libwrt 的特定修改"

    # 修改默认IP
    if [[ "$WORKFLOW_NAME" == "AXT-1800" ]]; then
        set_default_ip "192.168.8.1" "AXT-1800"
    elif [[ "$WORKFLOW_NAME" == "JDC-AX6600" ]]; then
        set_default_ip "192.168.100.1" "JDC-AX6600"
    fi

    wget https://raw.githubusercontent.com/m0eak/openwrt_patch/refs/heads/main/gl-axt1800/9999-gl-axt1800-dts-change-cooling-level.patch && echo "下载成功" || echo "下载失败"
    mv 9999-gl-axt1800-dts-change-cooling-level.patch ./target/linux/qualcommax/patches-6.12/9999-gl-axt1800-dts-change-cooling-level.patch && echo "移动成功" || echo "移动失败"
    rm -f package/kernel/mac80211/patches/nss/ath11k/999-902-ath11k-fix-WDS-by-disabling-nwds.patch && echo "删除patch1成功"
    rm -f package/kernel/mac80211/patches/nss/subsys/999-775-wifi-mac80211-Changes-for-WDS-MLD.patch && echo "删除patch2成功"

# --- 逻辑块 2: 处理 x86 immortalwrt ---
elif [[ "$WORKFLOW_NAME" == "x86_immortalwrt" ]]; then
    echo ">>> 检测到: $WORKFLOW_NAME。开始执行 x86 immortalwrt 的特定修改"
    
    VERSION2=${TAG2#v}
    echo "immortalwrt 当前版本 (VERSION2): $VERSION2"

    # 修改默认IP
    set_default_ip "192.168.100.1" "x86"

    # 修改版本号
    if [ -n "$VERSION2" ]; then
        sed -i "s/replace/$VERSION2/g" $GITHUB_WORKSPACE/files/etc/uci-defaults/zzz_m0eak && echo "VERSION替换成功"
    else
        echo "警告: VERSION2 为空，跳过版本号替换。"
    fi

# --- 逻辑块 3: 处理 TR-3000 ---
elif [[ "$WORKFLOW_NAME" == "TR-3000" ]]; then
    echo ">>> 检测到设备: $WORKFLOW_NAME。开始执行 TR-3000 的特定修改"

# --- 逻辑块 4: 处理 GL-MT3600BE ---
elif [[ "$WORKFLOW_NAME" == "GL-MT3600BE" ]]; then
    echo ">>> 检测到设备: $WORKFLOW_NAME。开始执行 MT3600BE 的特定修改"

    CUSTOM_DTS_URL="https://raw.githubusercontent.com/openwrt/openwrt/cced8d95f3caa9f48eaeb4ef2d15426d20afaf16/target/linux/mediatek/dts/mt7987a-glinet-gl-mt3600be.dts"
    CUSTOM_DTS_TARGET="target/linux/mediatek/dts/mt7987a-glinet-gl-mt3600be.dts"
    CUSTOM_DTS_TMP="/tmp/mt7987a-glinet-gl-mt3600be.dts"

    if [[ -f "$CUSTOM_DTS_TARGET" ]]; then
        echo "开始下载自定义 MT3600BE DTS..."
        curl -fL "$CUSTOM_DTS_URL" -o "$CUSTOM_DTS_TMP"

        echo "校验下载到的 DTS..."
        grep -q 'GL-MT3600BE' "$CUSTOM_DTS_TMP"
        grep -q 'cooling-levels' "$CUSTOM_DTS_TMP"

        cp "$CUSTOM_DTS_TMP" "$CUSTOM_DTS_TARGET"
        echo "已替换 $CUSTOM_DTS_TARGET"
        echo "cooling-levels 片段:"
        grep -n 'cooling-levels' "$CUSTOM_DTS_TARGET"
    else
        echo "错误: 未找到目标 DTS 文件 $CUSTOM_DTS_TARGET"
        exit 1
    fi

    set_default_ip "192.168.9.1" "mt3600be"

# --- 逻辑块 5: 处理 GL-MT5000 (OpenWrt Basis) ---
elif [[ "$WORKFLOW_NAME" == "GL-MT5000" ]]; then
    echo ">>> 检测到设备: $WORKFLOW_NAME。开始执行 MT5000 的特定修改"
    # 源码: GLiNet-Tech/openwrt @ mt5000 (OpenWrt main, RTL8366UB DSA 驱动已内置内核)
    set_default_ip "192.168.100.1" "mt5000"

# --- 逻辑块 6: 处理 gl-mt5000_immortalwrt (ImmortalWrt Basis + Patches) ---
elif [[ "$WORKFLOW_NAME" == "gl-mt5000_immortalwrt" ]]; then
    echo ">>> 检测到设备: $WORKFLOW_NAME。开始向 ImmortalWrt 导入 GL-MT5000 驱动与板级支持"

    GL_TMP_DIR="/tmp/glinet_mt5000_source"
    rm -rf "$GL_TMP_DIR"
    git clone --depth 1 -b mt5000 https://github.com/GLiNet-Tech/openwrt.git "$GL_TMP_DIR"

    if [[ -d "$GL_TMP_DIR" ]]; then
        echo "1. 复制 Device Tree (DTS)..."
        mkdir -p target/linux/mediatek/dts
        mkdir -p target/linux/mediatek/files/arch/arm64/boot/dts/mediatek
        cp -f "$GL_TMP_DIR"/target/linux/mediatek/dts/*gl-mt5000* target/linux/mediatek/dts/ 2>/dev/null || true
        cp -f "$GL_TMP_DIR"/target/linux/mediatek/files/arch/arm64/boot/dts/mediatek/*gl-mt5000* target/linux/mediatek/files/arch/arm64/boot/dts/mediatek/ 2>/dev/null || true

        echo "2. 复制 Base-Files (硬件配置与初始化脚本)..."
        mkdir -p target/linux/mediatek/filogic/base-files
        cp -rf "$GL_TMP_DIR"/target/linux/mediatek/filogic/base-files/* target/linux/mediatek/filogic/base-files/ 2>/dev/null || true

        echo "3. 检查并注入 filogic.mk 设备定义..."
        if ! grep -q "glinet_gl-mt5000" target/linux/mediatek/image/filogic.mk 2>/dev/null; then
            sed -n '/define Device\/glinet_gl-mt5000/,/endef/p' "$GL_TMP_DIR"/target/linux/mediatek/image/filogic.mk >> target/linux/mediatek/image/filogic.mk
            echo "Device/glinet_gl-mt5000 已追加到 filogic.mk"
        else
            echo "filogic.mk 中已存在 glinet_gl-mt5000 定义，跳过追加"
        fi

        echo "4. 复制 Kernel-Patches für Realtek Switch/DSA..."
        mkdir -p target/linux/mediatek/patches-6.18
        cp -f "$GL_TMP_DIR"/target/linux/mediatek/patches-*/*rtl8366* target/linux/mediatek/patches-6.18/ 2>/dev/null || true
        cp -f "$GL_TMP_DIR"/target/linux/mediatek/patches-*/*realtek* target/linux/mediatek/patches-6.18/ 2>/dev/null || true

        echo "5. Kernel-Konfiguration um Realtek DSA und RTL8366 erweitern..."
        for cfg in target/linux/mediatek/filogic/config-*; do
            if [ -f "$cfg" ]; then
                echo "CONFIG_NET_DSA_REALTEK=y" >> "$cfg"
                echo "CONFIG_NET_DSA_REALTEK_RTL8366RB=y" >> "$cfg"
                echo "CONFIG_NET_DSA_REALTEK_SMI=y" >> "$cfg"
                echo "CONFIG_NET_DSA_TAG_RTL4_A=y" >> "$cfg"
                echo "CONFIG_NET_DSA_TAG_NONE=y" >> "$cfg"
            fi
        done

        rm -rf "$GL_TMP_DIR"
        echo "GL-MT5000 板级支持导入成功！"
    else
        echo "警告: 克隆 GL.iNet MT5000 分支失败，请检查网络或仓库地址！"
    fi

    # Footstrap Theme Feed hinzufügen
    echo "src-git footstrap https://github.com/VizzleTF/luci-theme-footstrap.git" >> "feeds.conf.default"

    # 默认 IP 设置
    set_default_ip "192.168.100.1" "mt5000-immortalwrt"

else
    echo ">>> 未匹配到任何已知的 WORKFLOW_NAME ('$WORKFLOW_NAME')。跳过所有设备特定的修改"
fi

echo "--- DIY Part 1 脚本执行完毕 ---"
