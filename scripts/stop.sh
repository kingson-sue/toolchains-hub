#!/usr/bin/env bash
# 停止并移除容器（不删除 data/、workspace/ 与镜像）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

cd "${PROJECT_ROOT}"
docker_compose down "$@"
echo "[ok] 容器已停止"
