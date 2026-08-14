#!/usr/bin/env bash
# 导出/打包 data 目录（不含 workspace，workspace 与 data 同级，随工程目录一起拷贝）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

OUT="${1:-${PROJECT_ROOT}/toolchains-hub-data-$(date +%Y%m%d).tar.gz}"

echo "打包数据目录: ${IDF_DATA_ROOT}"
echo "输出: ${OUT}"
echo "提示: 体积可能很大（含工具链），请耐心等待..."
echo "提示: workspace/ 不在 data 内，请连同工程目录一起拷贝"

tar -C "$(dirname "${IDF_DATA_ROOT}")" \
    -czf "${OUT}" \
    "$(basename "${IDF_DATA_ROOT}")"

echo "[ok] 已生成: ${OUT}"
ls -lh "${OUT}"
