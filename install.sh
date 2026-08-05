#!/bin/sh
# 一键获取最新 build.sh 并在 OpenWrt 源码根目录执行
# 用法（在 OpenWrt 源码根目录）:
#   curl -fsSL https://raw.githubusercontent.com/hrimfaxi/openwrt-tutu-all-in-1/master/install.sh | sh
#   或传参: ... | sh -s V=s -j$(nproc) IGNORE_ERRORS=1
set -e

REPO="hrimfaxi/openwrt-tutu-all-in-1"
BRANCH="master"
URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/build.sh"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo ">>> 下载 build.sh ..."
curl -fsSL "$URL" -o "$TMP"
chmod +x "$TMP"

echo ">>> 执行 build.sh $*"
"$TMP" "$@"
