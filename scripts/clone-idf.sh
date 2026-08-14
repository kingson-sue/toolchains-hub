#!/usr/bin/env bash
# 从 GitHub 拉取 / 更新 ESP-IDF 到 data/sdk/esp/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

clone_or_update() {
    local dest="$1"
    local url="$2"
    local ref="$3"
    local name
    name="$(basename "${dest}")"

    if [[ -z "${url}" ]]; then
        echo "[error] ${name}: URL 为空，请检查 config.env 中的 IDF_URL" >&2
        exit 1
    fi

    mkdir -p "$(dirname "${dest}")"
    if [[ -d "${dest}/.git" ]] || [[ -f "${dest}/.git" ]]; then
        echo "[info] 更新 ${name} (${ref}) ..."
        git -C "${dest}" remote set-url origin "${url}"
        git -C "${dest}" fetch --tags --prune origin
        if [[ "${ref}" != "HEAD" ]]; then
            if git -C "${dest}" show-ref --verify --quiet "refs/remotes/origin/${ref}"; then
                git -C "${dest}" checkout -B "${ref}" "origin/${ref}"
            elif git -C "${dest}" show-ref --verify --quiet "refs/tags/${ref}"; then
                git -C "${dest}" checkout --detach "tags/${ref}"
            else
                git -C "${dest}" checkout --detach "${ref}"
            fi
        fi
        if [[ -f "${dest}/.gitmodules" ]]; then
            git -C "${dest}" submodule update --init --recursive
        fi
    else
        echo "[info] 克隆 ${name} <- ${url} (${ref}) ..."
        if [[ "${ref}" != "HEAD" ]] && git clone --recursive --branch "${ref}" --single-branch "${url}" "${dest}"; then
            :
        else
            rm -rf "${dest}"
            git clone --recursive "${url}" "${dest}"
            if [[ "${ref}" != "HEAD" ]]; then
                git -C "${dest}" checkout "${ref}"
            fi
            git -C "${dest}" submodule update --init --recursive
        fi
    fi

    echo "[ok] ${dest} @ $(git -C "${dest}" rev-parse --short HEAD) ($(git -C "${dest}" describe --tags --always 2>/dev/null || true))"
}

echo "=== 拉取 ESP-IDF ==="
echo "目标目录: ${ESP_DIR}/${IDF_NAME}"
echo "仓库    : ${IDF_URL}"
echo "版本    : ${IDF_REF}"
echo

clone_or_update "${ESP_DIR}/${IDF_NAME}" "${IDF_URL}" "${IDF_REF}"

echo
echo "=== ESP-IDF 仓库就绪 ==="
ls -la "${ESP_DIR}"
