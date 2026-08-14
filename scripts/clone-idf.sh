#!/usr/bin/env bash
# 从 GitHub 拉取 / 更新 ESP-IDF 到 data/sdk/esp/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# GitHub 不允许按任意 SHA fetch（upload-pack: not our ref）。
# git fetch 默认 fetch.recurseSubmodules=on-demand：父仓库一旦拉到新 tag/提交，
# 就会去请求对应的历史子模块 SHA。ESP-IDF 里大量旧 gitlink 在 GitHub 上已不可达，
# 于是出现 lwip / esp_wifi / bt-lib 等 submodule fetch 失败。
disable_recursive_fetch() {
    local dest="$1"
    git -C "${dest}" config fetch.recurseSubmodules false
}

update_submodules() {
    local dest="$1"
    if [[ ! -f "${dest}/.gitmodules" ]]; then
        return 0
    fi
    echo "[info] 同步子模块 ..."
    git -C "${dest}" submodule sync --recursive
    git -C "${dest}" submodule update --init --recursive
}

checkout_ref() {
    local dest="$1"
    local ref="$2"
    if [[ "${ref}" == "HEAD" ]]; then
        return 0
    fi
    if git -C "${dest}" show-ref --verify --quiet "refs/tags/${ref}"; then
        git -C "${dest}" checkout --detach "tags/${ref}"
    elif git -C "${dest}" rev-parse --verify --quiet "refs/remotes/origin/${ref}"; then
        git -C "${dest}" checkout -B "${ref}" "origin/${ref}"
    else
        git -C "${dest}" checkout --detach "${ref}"
    fi
}

already_at_ref() {
    local dest="$1"
    local ref="$2"
    local head wanted

    if [[ "${ref}" == "HEAD" ]]; then
        return 0
    fi

    head="$(git -C "${dest}" rev-parse HEAD)"
    if wanted="$(git -C "${dest}" rev-parse --verify --quiet "refs/tags/${ref}^{commit}")"; then
        [[ "${wanted}" == "${head}" ]]
        return
    fi
    if wanted="$(git -C "${dest}" rev-parse --verify --quiet "refs/remotes/origin/${ref}")"; then
        [[ "${wanted}" == "${head}" ]]
        return
    fi
    if wanted="$(git -C "${dest}" rev-parse --verify --quiet "${ref}^{commit}")"; then
        [[ "${wanted}" == "${head}" ]]
        return
    fi
    return 1
}

fetch_ref() {
    local dest="$1"
    local ref="$2"
    if [[ "${ref}" == "HEAD" ]]; then
        git -C "${dest}" fetch --prune --recurse-submodules=no origin
        return
    fi
    # 只拉目标 ref，不要 --tags：后者会把所有历史 tag 拉下来并触发子模块 SHA fetch
    git -C "${dest}" fetch --prune --recurse-submodules=no origin "${ref}"
}

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
        disable_recursive_fetch "${dest}"
        if already_at_ref "${dest}" "${ref}"; then
            echo "[info] ${name} 已在 ${ref}，跳过 fetch"
        else
            fetch_ref "${dest}" "${ref}"
            checkout_ref "${dest}" "${ref}"
        fi
        update_submodules "${dest}"
    else
        echo "[info] 克隆 ${name} <- ${url} (${ref}) ..."
        # 先只克隆父仓库，再单独更新当前树的子模块，避免 clone --recursive
        # 在部分失败后留下半成品，也避免 --single-branch + 后续 fetch --tags 踩坑
        if [[ "${ref}" != "HEAD" ]] && git clone --branch "${ref}" --single-branch "${url}" "${dest}"; then
            :
        else
            rm -rf "${dest}"
            git clone "${url}" "${dest}"
            checkout_ref "${dest}" "${ref}"
        fi
        disable_recursive_fetch "${dest}"
        update_submodules "${dest}"
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
