#!/usr/bin/env bash
# 在已运行的容器内，为 ESP-IDF 6.0.2 安装工具链 + Python venv
# 结果写入宿主机 ${IDF_DATA_ROOT}/tools/，可随数据目录一起迁移
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if ! docker_run ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    echo "[error] 容器 ${CONTAINER_NAME} 未运行，请先执行 scripts/deploy.sh" >&2
    exit 1
fi

mkdir -p "${TOOLS_ROOT}/${IDF_TOOLS_DIR}/python_env/${IDF_PYTHON_ENV}"

echo
echo "=== 安装工具: IDF ${IDF_VERSION} (targets=${IDF_INSTALL_TARGETS}) ==="
echo "下载源: IDF_GITHUB_ASSETS=${IDF_GITHUB_ASSETS}, PIP_INDEX_URL=${PIP_INDEX_URL}"
docker_run exec \
    -e HOME="${CONTAINER_HOME}" \
    -e IDF_GITHUB_ASSETS="${IDF_GITHUB_ASSETS}" \
    -e PIP_INDEX_URL="${PIP_INDEX_URL}" \
    -e PIP_TRUSTED_HOST="${PIP_TRUSTED_HOST}" \
    -e PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT}" \
    -w "${CONTAINER_HOME}" "${CONTAINER_NAME}" \
    bash -lc "
        set -euo pipefail
            source /etc/profile.d/toolchain-home.sh 2>/dev/null || true
        unset PYTHONPATH VIRTUAL_ENV
        export IDF_TOOLS_PATH=${CONTAINER_HOME}/.espressif
        export IDF_PATH=${CONTAINER_HOME}/sdk/esp/${IDF_NAME}
        export ESP_IDF_VERSION=${IDF_VERSION}
        export IDF_PYTHON_ENV_PATH=${CONTAINER_HOME}/.espressif/python_env/${IDF_PYTHON_ENV}
        if [[ ! -f \"\${IDF_PATH}/install.sh\" ]]; then
            echo \"[error] 找不到 \${IDF_PATH}/install.sh\" >&2
            exit 1
        fi
        mkdir -p \"\${IDF_PYTHON_ENV_PATH}\"
        cd \"\${IDF_PATH}\"
        bash ./install.sh ${IDF_INSTALL_TARGETS}
        echo \"[ok] IDF ${IDF_VERSION} tools installed -> \${IDF_TOOLS_PATH}\"
    "

echo
echo "=== 工具安装完成 ==="
echo "工具目录: ${TOOLS_ROOT}/${IDF_TOOLS_DIR}"
