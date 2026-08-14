#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

SYNC_PORT=true

usage() {
    cat <<EOF
用法: $(basename "$0") [选项]

选项:
  --no-root     不查询容器实际端口（不需要 sudo），直接用 config.env 中的 SSH_HOST_PORT
  -h, --help    显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-root) SYNC_PORT=false; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "[error] 未知参数: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ "${SYNC_PORT}" == "true" ]]; then
    actual_ssh_port="$(container_ssh_port || true)"

    if [[ -n "${actual_ssh_port}" && "${actual_ssh_port}" != "${SSH_HOST_PORT}" ]]; then
        echo "[info] 配置端口 ${SSH_HOST_PORT:-<空>} 与容器 ${CONTAINER_NAME} 的实际端口不一致，更新为 ${actual_ssh_port}"
        SSH_HOST_PORT="${actual_ssh_port}"
        export SSH_HOST_PORT
        set_config_value SSH_HOST_PORT "${SSH_HOST_PORT}"
        write_compose_env
    fi
fi

if [[ -z "${SSH_HOST_PORT}" ]]; then
    echo "[error] 找不到 ${CONTAINER_NAME} 的 SSH 端口，请先执行 make deploy 或 make deploy-no-build" >&2
    exit 1
fi

ssh_opts=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o LogLevel=ERROR
    -p "${SSH_HOST_PORT}"
)
ssh_target="${CONTAINER_USER}@127.0.0.1"

if [[ -n "${SSH_PASSWORD}" ]]; then
    if command -v sshpass >/dev/null 2>&1; then
        exec sshpass -p "${SSH_PASSWORD}" ssh "${ssh_opts[@]}" "${ssh_target}"
    fi
    echo "[warn] 未安装 sshpass，无法自动填写容器密码；可执行 sudo apt-get install -y sshpass" >&2
fi

exec ssh "${ssh_opts[@]}" "${ssh_target}"
