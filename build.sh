#!/bin/bash
# 集成构建脚本：克隆、更新、编译所有定制包
# 用法: ./build.sh [make参数...]
# 示例: ./build.sh V=s -j$(nproc) IGNORE_ERRORS=1

set -e  # 出错即停

# ============================================================
# 0. 解析并保存用户传入的 make 参数（默认为空）
# ============================================================
MAKE_ARGS=("$@")
if [ "${#MAKE_ARGS[@]}" -gt 0 ]; then
    echo ">>> 检测到自定义 make 参数: ${MAKE_ARGS[*]}"
else
    echo ">>> 未传入额外参数，将使用默认静默模式编译（如需调试请传入 V=s）"
fi

# ============================================================
# 1. 确保在 OpenWrt 源码根目录
# ============================================================
OPENWRT_ROOT="$(pwd)"
if [ ! -f scripts/feeds ]; then
    echo "错误：请在 OpenWrt 源码根目录执行此脚本（该目录应包含 scripts/feeds）"
    exit 1
fi

# 替换 feeds 源为 GitHub（国内加速/防屏蔽）
if [ -f feeds.conf.default ]; then
    sed -i -E 's;git.openwrt.org/(feed|project);github.com/openwrt;' feeds.conf.default
fi

# ============================================================
# 2. 克隆所有仓库到 package 目录
# ============================================================
mkdir -p package
cd package

declare -A REPOS=(
    ["tutuicmptunnel"]="https://github.com/hrimfaxi/openwrt-tutuicmptunnel-kmod"
    ["strongDNS2"]="https://github.com/hrimfaxi/openwrt-strongDNS2"
    ["tsubamegaeshi-rs"]="https://github.com/hrimfaxi/openwrt-tsubamegaeshi-rs.git"
    ["luci-app-tsubamegaeshi-rs"]="https://github.com/hrimfaxi/luci-app-tsubamegaeshi-rs.git"
    ["tumgrd"]="https://github.com/hrimfaxi/openwrt-tumgrd"
    ["luci-app-tumgrd"]="https://github.com/hrimfaxi/luci-app-tumgrd"
    ["xtp-rs"]="https://github.com/hrimfaxi/openwrt-xtp-rs.git"
    ["shadowquic"]="https://github.com/hrimfaxi/openwrt-shadowquic.git"
)

for pkg in "${!REPOS[@]}"; do
    if [ -d "$pkg" ]; then
        echo ">>> 跳过已存在的仓库: $pkg"
    else
        echo ">>> 克隆 $pkg ..."
        git clone "${REPOS[$pkg]}" "$pkg" || {
            echo "警告：克隆 $pkg 失败，继续执行..."
        }
    fi
done

# 安全返回源码根目录
cd "$OPENWRT_ROOT"

# ============================================================
# 3. 更新 & 安装 feeds
# ============================================================
echo ">>> 更新 feeds ..."
./scripts/feeds update -a -f

echo ">>> 按需安装 feeds 依赖（仅目标包及其递归依赖）..."
./scripts/feeds install \
    tutuicmptunnel \
    strongDNS2 \
    tsubamegaeshi-rs \
    luci-app-tsubamegaeshi-rs \
    tumgrd \
    luci-app-tumgrd \
    xtp-rs \
    shadowquic \
    sqlite3 \
    ubus \
    ubox \
    libmnl \
    libnetfilter-queue \
    libnfnetlink \
    luci-base

# ============================================================
# 4. 定义构建函数（自动附加 $MAKE_ARGS）
# ============================================================
build_pkg() {
    local target="$1"
    echo ">>> 编译 $target ..."
    make "package/${target}/compile" "${MAKE_ARGS[@]}"
}

# ============================================================
# 5. 按依赖顺序编译
# ============================================================
# 基础依赖优先
build_pkg sqlite3
build_pkg ubus
build_pkg ubox

# 网络工具
build_pkg tutuicmptunnel
build_pkg strongDNS2
build_pkg xtp-rs
build_pkg shadowquic

# tsubamegaeshi-rs 主程序 → LuCI 应用
build_pkg tsubamegaeshi-rs
build_pkg luci-app-tsubamegaeshi-rs

# tumgrd 主程序 → LuCI 应用
build_pkg tumgrd
build_pkg luci-app-tumgrd

# ============================================================
# 6. 查找生成的安装包
# ============================================================
echo "=============================================="
echo "✅ 构建完成！查找生成的 .ipk / .apk 文件："
FOUND=$(find bin/ -type f \( \
    -name "*tutu*.ipk" -o -name "*tutu*.apk" \
    -o -name "*strongDNS2*.ipk" -o -name "*strongDNS2*.apk" \
    -o -name "*tsubamegaeshi*.ipk" -o -name "*tsubamegaeshi*.apk" \
    -o -name "*tumgrd*.ipk" -o -name "*tumgrd*.apk" \
    -o -name "*shadowquic*.ipk" -o -name "*shadowquic*.apk" \
    -o -name "*xtp*.ipk" -o -name "*xtp*.apk" \
\) 2>/dev/null || true)
if [ -n "$FOUND" ]; then
    echo "$FOUND"
else
    echo "⚠️  未找到相关包，请检查编译日志。"
fi

echo ">>> 脚本结束。"
