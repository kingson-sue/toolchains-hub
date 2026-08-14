#!/usr/bin/env bash
# 查看部署状态
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

echo "=== 配置 ==="
echo "工程: ${PROJECT_ROOT}"
echo "数据: ${IDF_DATA_ROOT}"
echo "工作区: ${IDF_WORKSPACE}"
echo "镜像: ${IMAGE_REF}"
echo "容器: ${CONTAINER_NAME}"
echo "SSH : ${SSH_HOST_PORT}"
echo "IDF : ${IDF_NAME} (${IDF_REF})"
echo

echo "=== 容器 ==="
docker_run ps -a --filter "name=${CONTAINER_NAME}" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' || true
echo

echo "=== ESP-IDF 仓库 ==="
dest="${ESP_DIR}/${IDF_NAME}"
if [[ -d "${dest}/.git" ]] || [[ -f "${dest}/.git" ]]; then
    echo "- ${IDF_NAME}: $(git -C "${dest}" rev-parse --short HEAD) ($(git -C "${dest}" describe --tags --always 2>/dev/null || echo '?')) ref=$(git -C "${dest}" rev-parse --abbrev-ref HEAD)"
else
    echo "- ${IDF_NAME}: <未克隆>"
fi
echo

echo "=== 工具目录 ==="
p="${TOOLS_ROOT}/${IDF_TOOLS_DIR}"
if [[ -d "${p}/tools" || -d "${p}/python_env" ]]; then
    echo "- ${IDF_TOOLS_DIR}: OK ($(du -sh "${p}" 2>/dev/null | awk '{print $1}'))"
else
    echo "- ${IDF_TOOLS_DIR}: <未安装或为空>"
fi
