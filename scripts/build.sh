#!/usr/bin/env bash
# 构建 Docker 镜像
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

cd "${PROJECT_ROOT}"

echo "=== 构建镜像 ${IMAGE_REF} ==="
echo "基础镜像: ${BASE_IMAGE}"
echo "SSH 默认密码将写入镜像: ${SSH_PASSWORD}"

docker_compose build \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
    --build-arg SSH_PASSWORD="${SSH_PASSWORD}" \
    --build-arg CONTAINER_HOME="${CONTAINER_HOME}"

echo
echo "[ok] 镜像构建完成: ${IMAGE_REF}"
docker_run images "${IMAGE_NAME}" --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}'
