#!/usr/bin/env bash
# 一键部署：拉取 IDF -> 构建镜像 -> 启动容器 ->（可选）安装工具链
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

SKIP_BUILD=false
SKIP_CLONE=false
SKIP_TOOLS=false
FORCE_RECREATE=false

usage() {
    cat <<EOF
用法: $(basename "$0") [选项]

选项:
  --skip-build      不重新构建镜像
  --skip-clone      不拉取/更新 IDF 仓库
  --skip-tools      不安装工具链/venv（覆盖 config.env 中 INSTALL_TOOLS）
  --with-tools      强制安装工具链（覆盖 config.env）
  --force-recreate  强制重建容器
  -h, --help        显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build) SKIP_BUILD=true; shift ;;
        --skip-clone) SKIP_CLONE=true; shift ;;
        --skip-tools) SKIP_TOOLS=true; shift ;;
        --with-tools) INSTALL_TOOLS=true; SKIP_TOOLS=false; shift ;;
        --force-recreate) FORCE_RECREATE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "[error] 未知参数: $1" >&2; usage; exit 1 ;;
    esac
done

ensure_ssh_host_port

echo "========================================"
echo " Toolchains Hub 部署"
echo " 工程目录 : ${PROJECT_ROOT}"
echo " 数据目录 : ${IDF_DATA_ROOT}"
echo " 工作区   : ${IDF_WORKSPACE}"
echo " 镜像     : ${IMAGE_REF}"
echo " 容器     : ${CONTAINER_NAME}"
echo " SSH 端口 : ${SSH_HOST_PORT}"
echo " IDF      : ${IDF_NAME} (${IDF_REF})"
echo "========================================"
echo

if [[ "${SKIP_CLONE}" != "true" ]]; then
    "${SCRIPT_DIR}/clone-idf.sh"
else
    echo "[info] 跳过 IDF 仓库拉取"
fi

if [[ "${SKIP_BUILD}" != "true" ]]; then
    "${SCRIPT_DIR}/build.sh"
else
    echo "[info] 跳过镜像构建"
fi

cd "${PROJECT_ROOT}"
write_compose_env

UP_ARGS=(-d)
if [[ "${SKIP_BUILD}" == "true" ]]; then
    UP_ARGS+=(--no-build)
fi
if [[ "${FORCE_RECREATE}" == "true" ]]; then
    UP_ARGS+=(--force-recreate)
fi

echo
echo "=== 启动容器 ==="
docker_compose up "${UP_ARGS[@]}"

echo -n "[info] 等待 SSH 就绪"
for _ in $(seq 1 30); do
    if docker_run exec "${CONTAINER_NAME}" true 2>/dev/null; then
        echo " OK"
        break
    fi
    echo -n "."
    sleep 1
done

if [[ "${SKIP_TOOLS}" == "true" ]]; then
    echo "[info] 跳过工具链安装"
elif [[ "${INSTALL_TOOLS}" == "true" ]]; then
    "${SCRIPT_DIR}/install-tools.sh"
else
    echo "[info] INSTALL_TOOLS=false，跳过工具链安装"
    echo "      需要时执行: ./scripts/install-tools.sh"
fi

cat <<EOF

========================================
 部署完成

 SSH 登录:
   ssh -p ${SSH_HOST_PORT} ${CONTAINER_USER}@127.0.0.1
   密码: ${SSH_PASSWORD}

 切换开发环境:
   esp_idf
   idf_status

 数据目录:
   ${IDF_DATA_ROOT}
     sdk/          # ESP-IDF git 仓库
     tools/        # 工具链 + Python venv
 工作区（与 data/ 同级）:
   ${IDF_WORKSPACE}
========================================
EOF
