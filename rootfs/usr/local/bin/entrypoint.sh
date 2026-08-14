#!/bin/bash
set -euo pipefail

HOME_DIR="${CONTAINER_HOME:-/usmile}"
USER_NAME="${CONTAINER_USER:-usmile}"
HOST_UID="${HOST_UID:-}"
HOST_GID="${HOST_GID:-}"
export HOME="${HOME_DIR}"

# 把容器登录用户对齐到宿主机 UID/GID，避免 bind mount 的 workspace 权限冲突
sync_user_ids() {
    if ! id "${USER_NAME}" >/dev/null 2>&1; then
        return 0
    fi
    if [[ -z "${HOST_UID}" || -z "${HOST_GID}" ]]; then
        return 0
    fi

    local cur_uid cur_gid primary_group
    cur_uid="$(id -u "${USER_NAME}")"
    cur_gid="$(id -g "${USER_NAME}")"
    primary_group="$(id -gn "${USER_NAME}")"

    if [[ "${cur_gid}" != "${HOST_GID}" ]]; then
        if getent group "${HOST_GID}" >/dev/null 2>&1; then
            usermod -g "${HOST_GID}" "${USER_NAME}" || true
        else
            groupmod -o -g "${HOST_GID}" "${primary_group}" || true
        fi
    fi

    if [[ "${cur_uid}" != "${HOST_UID}" ]]; then
        usermod -o -u "${HOST_UID}" "${USER_NAME}" || true
    fi
}

# 若 workspace 对登录用户不可写（常见于之前用 root 编译留下的文件），自动修正属主
fix_workspace_owner() {
    local ws="${HOME_DIR}/workspace"
    [[ -d "${ws}" ]] || return 0

    if su -s /bin/bash "${USER_NAME}" -c \
        "test -w '${ws}' && touch '${ws}/.write_test' && rm -f '${ws}/.write_test'"; then
        return 0
    fi

    echo "[info] fixing ownership of ${ws} -> ${USER_NAME} (${HOST_UID:-?}:${HOST_GID:-?})"
    chown -R "${USER_NAME}:${USER_NAME}" "${ws}" || true
}

sync_user_ids
fix_workspace_owner

mkdir -p \
    "${HOME_DIR}/sdk" \
    "${HOME_DIR}/workspace" \
    "${HOME_DIR}/.espressif" \
    "${HOME_DIR}/.ssh"

if [ -f "${HOME_DIR}/.bashrc" ] && [ ! -e /root/.bashrc ]; then
    ln -sf "${HOME_DIR}/.bashrc" /root/.bashrc
fi
if [ -f "${HOME_DIR}/.profile" ] && [ ! -e /root/.profile ]; then
    ln -sf "${HOME_DIR}/.profile" /root/.profile
fi

cat <<EOF
========================================
 Toolchains Hub ready
 SSH  : host port -> container 22
 User : ${USER_NAME} (uid=${HOST_UID:-default} gid=${HOST_GID:-default})
 HOME : ${HOME_DIR}

 Activate:
  esp_idf
========================================
EOF

exec "$@"
