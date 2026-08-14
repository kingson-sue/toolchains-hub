#!/usr/bin/env bash
# 加载工程配置；所有脚本应 source 本文件
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIG_FILE="${PROJECT_ROOT}/config.env"
EXAMPLE_FILE="${PROJECT_ROOT}/config.env.example"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    if [[ -f "${EXAMPLE_FILE}" ]]; then
        echo "[info] 未找到 config.env，正在从 config.env.example 复制..."
        cp "${EXAMPLE_FILE}" "${CONFIG_FILE}"
    else
        echo "[error] 缺少 config.env 与 config.env.example" >&2
        exit 1
    fi
fi

# shellcheck disable=SC1090
set -a
source "${CONFIG_FILE}"
set +a

# 默认数据根目录：工程内 data/
if [[ -z "${IDF_DATA_ROOT:-}" ]]; then
    IDF_DATA_ROOT="${PROJECT_ROOT}/data"
fi
# 展开 ~
IDF_DATA_ROOT="${IDF_DATA_ROOT/#\~/${HOME}}"

# 工作区默认与 data/ 同级，不放在 data 下
if [[ -z "${IDF_WORKSPACE:-}" ]]; then
    IDF_WORKSPACE="${PROJECT_ROOT}/workspace"
fi
IDF_WORKSPACE="${IDF_WORKSPACE/#\~/${HOME}}"

host_user="${SUDO_USER:-${USER:-$(id -un)}}"
name_suffix="$(printf '%s' "${host_user}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.-]+/-/g; s/^-+//; s/-+$//')"
name_suffix="${name_suffix:-user}"

IMAGE_NAME="${IMAGE_NAME:-toolchains-hub}"
IMAGE_TAG="${IMAGE_TAG:-multi}"
IMAGE_REF="${IMAGE_NAME}:${IMAGE_TAG}"
BASE_IMAGE="${BASE_IMAGE:-docker.m.daocloud.io/library/ubuntu:22.04}"
DOCKER_USE_SUDO="${DOCKER_USE_SUDO:-false}"
CONTAINER_NAME="${CONTAINER_NAME:-toolchains-hub-${name_suffix}}"
SSH_HOST_PORT="${SSH_HOST_PORT:-}"
SSH_HOST_PORT_START="${SSH_HOST_PORT_START:-3022}"
SSH_PASSWORD="${SSH_PASSWORD:-toolchain168}"
MOUNT_HOST_SSH="${MOUNT_HOST_SSH:-true}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
IDF_INSTALL_TARGETS="${IDF_INSTALL_TARGETS:-esp32,esp32s3}"
IDF_GITHUB_ASSETS="${IDF_GITHUB_ASSETS:-dl.espressif.com/github_assets}"
PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
PIP_TRUSTED_HOST="${PIP_TRUSTED_HOST:-pypi.tuna.tsinghua.edu.cn}"
PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-120}"

# 容器内固定 HOME，与宿主机用户名无关，便于迁移
CONTAINER_HOME="${CONTAINER_HOME:-/toolchain}"
CONTAINER_USER="${CONTAINER_USER:-toolchain}"

# 宿主机 UID/GID：容器启动时对齐 toolchain，避免 workspace 权限冲突
if [[ -z "${HOST_UID:-}" || -z "${HOST_GID:-}" ]]; then
    if [[ "$(id -u)" != "0" ]]; then
        HOST_UID="$(id -u)"
        HOST_GID="$(id -g)"
    elif [[ -d "${IDF_WORKSPACE}" ]]; then
        HOST_UID="$(stat -c '%u' "${IDF_WORKSPACE}")"
        HOST_GID="$(stat -c '%g' "${IDF_WORKSPACE}")"
    else
        HOST_UID=1000
        HOST_GID=1000
    fi
fi

SDK_DIR="${IDF_DATA_ROOT}/sdk"
ESP_DIR="${SDK_DIR}/esp"
TOOLS_ROOT="${IDF_DATA_ROOT}/tools"

IDF_NAME="${IDF_NAME:-esp-idf-v6.0.2}"
IDF_URL="${IDF_URL:-https://github.com/espressif/esp-idf.git}"
IDF_REF="${IDF_REF:-v6.0.2}"
IDF_TOOLS_DIR="${IDF_TOOLS_DIR:-espressif}"
IDF_PYTHON_ENV="${IDF_PYTHON_ENV:-idf6.0.2_py3.10_env}"
IDF_VERSION="${IDF_VERSION:-6.0.2}"

mkdir -p \
    "${SDK_DIR}" \
    "${ESP_DIR}" \
    "${TOOLS_ROOT}" \
    "${IDF_WORKSPACE}" \
    "${TOOLS_ROOT}/${IDF_TOOLS_DIR}"

export PROJECT_ROOT CONFIG_FILE IDF_DATA_ROOT IDF_WORKSPACE
export IMAGE_NAME IMAGE_TAG IMAGE_REF BASE_IMAGE DOCKER_USE_SUDO CONTAINER_NAME
export SSH_HOST_PORT SSH_HOST_PORT_START SSH_PASSWORD
export MOUNT_HOST_SSH INSTALL_TOOLS IDF_INSTALL_TARGETS CONTAINER_HOME CONTAINER_USER
export HOST_UID HOST_GID
export IDF_GITHUB_ASSETS PIP_INDEX_URL PIP_TRUSTED_HOST PIP_DEFAULT_TIMEOUT
export SDK_DIR ESP_DIR TOOLS_ROOT
export IDF_NAME IDF_URL IDF_REF IDF_TOOLS_DIR IDF_PYTHON_ENV IDF_VERSION

# 供 docker compose 使用。默认按宿主机用户名隔离容器/网络等资源，镜像仍可共享。
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-toolchainshub-${name_suffix}}"

# 写出 .env，供 docker compose 变量替换（勿手改，改 config.env 后重新跑脚本即可）
write_compose_env() {
    cat > "${PROJECT_ROOT}/.env" <<EOF
# Auto-generated from config.env — do not edit by hand
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
IMAGE_NAME=${IMAGE_NAME}
IMAGE_TAG=${IMAGE_TAG}
BASE_IMAGE=${BASE_IMAGE}
CONTAINER_NAME=${CONTAINER_NAME}
SSH_HOST_PORT=${SSH_HOST_PORT}
SSH_PASSWORD=${SSH_PASSWORD}
CONTAINER_HOME=${CONTAINER_HOME}
CONTAINER_USER=${CONTAINER_USER}
HOST_UID=${HOST_UID}
HOST_GID=${HOST_GID}
IDF_DATA_ROOT=${IDF_DATA_ROOT}
SDK_DIR=${SDK_DIR}
IDF_WORKSPACE=${IDF_WORKSPACE}
IDF_NAME=${IDF_NAME}
IDF_TOOLS_DIR=${IDF_TOOLS_DIR}
HOST_SSH_DIR=${HOME}/.ssh
IDF_GITHUB_ASSETS=${IDF_GITHUB_ASSETS}
PIP_INDEX_URL=${PIP_INDEX_URL}
PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST}
PIP_DEFAULT_TIMEOUT=${PIP_DEFAULT_TIMEOUT}
EOF
}

write_compose_env

compose_files=(-f "${PROJECT_ROOT}/docker-compose.yml")
if [[ "${MOUNT_HOST_SSH}" == "true" && -d "${HOME}/.ssh" ]]; then
    compose_files+=(-f "${PROJECT_ROOT}/docker-compose.ssh.yml")
fi

docker_cmd=(docker)
if [[ "${DOCKER_USE_SUDO}" == "true" ]]; then
    docker_cmd=(sudo docker)
fi

docker_run() {
    "${docker_cmd[@]}" "$@"
}

docker_compose() {
    docker_run compose "${compose_files[@]}" "$@"
}

set_config_value() {
    local key="$1"
    local value="$2"
    local tmp
    local found=false

    tmp="$(mktemp)"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" == "${key}="* ]]; then
            printf '%s=%s\n' "${key}" "${value}"
            found=true
        else
            printf '%s\n' "${line}"
        fi
    done < "${CONFIG_FILE}" > "${tmp}"

    if [[ "${found}" != "true" ]]; then
        printf '\n%s=%s\n' "${key}" "${value}" >> "${tmp}"
    fi

    mv "${tmp}" "${CONFIG_FILE}"
}

container_ssh_port() {
    local published=""
    local line

    while IFS= read -r line; do
        published="${line}"
    done < <(docker_run port "${CONTAINER_NAME}" 22/tcp 2>/dev/null || true)

    [[ -n "${published}" ]] || return 1
    printf '%s\n' "${published##*:}"
}

port_is_free() {
    local port="$1"

    if command -v ss >/dev/null 2>&1; then
        ! ss -H -ltn "sport = :${port}" | grep -q .
        return
    fi

    ! (: >/dev/tcp/127.0.0.1/"${port}") >/dev/null 2>&1
}

choose_free_port() {
    local port="$1"
    port="${port:-${SSH_HOST_PORT_START}}"

    while ! port_is_free "${port}"; do
        port=$((port + 1))
    done

    printf '%s\n' "${port}"
}

ensure_ssh_host_port() {
    local current_port=""
    local selected_port

    if [[ -n "${SSH_HOST_PORT}" ]]; then
        current_port="$(container_ssh_port || true)"
        if [[ "${current_port}" == "${SSH_HOST_PORT}" ]]; then
            return
        fi
    fi

    if [[ -n "${SSH_HOST_PORT}" && -z "${current_port}" ]] && port_is_free "${SSH_HOST_PORT}"; then
        return
    fi

    selected_port="$(choose_free_port "${SSH_HOST_PORT}")"
    if [[ "${selected_port}" != "${SSH_HOST_PORT}" ]]; then
        echo "[info] SSH_HOST_PORT=${SSH_HOST_PORT:-<auto>} 不可用，自动选择 ${selected_port}"
        SSH_HOST_PORT="${selected_port}"
        export SSH_HOST_PORT
        set_config_value SSH_HOST_PORT "${SSH_HOST_PORT}"
    fi
}
