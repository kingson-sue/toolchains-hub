# 设计说明

## 相对原多版本工程的差异

1. 独立目录，整包拷贝即可带到另一台机器。
2. `workspace/` 与 `data/` 同级，不放在 `data/` 下。
3. 不挂载 `version_release_tool` / `tool/`。
4. ESP-IDF 来自 GitHub 官方仓库，不使用内网 GitLab。
5. 只装 ESP-IDF 6.0.2，不含 5.x / 6.1，也不含 Axera。

## 为什么 IDF 源码不打进镜像？

源码始终是 git 仓库。部署时 `make clone` 从 GitHub 拉到 `data/sdk/esp/`，再挂进容器。换机器时可以整包拷贝 `data/`，也可以在新机器重新 clone。

## 为什么工具链也不打进镜像？

工具链 + Python venv 体积大，且与 `IDF_INSTALL_TARGETS` 相关。装在 `data/tools/` 后可用 `export-data` 迁移，无需每次从 Espressif CDN 重下。安装过程在容器内执行，保证 `HOME=/usmile`、Python 3.10、glibc 环境一致。

## 路径约定

| 角色 | 路径 |
|------|------|
| 容器 HOME | `/usmile`（固定，与宿主机用户名无关） |
| SDK 源码 | `/usmile/sdk/esp/esp-idf-v6.0.2` ← 挂载自 `data/sdk/...` |
| 工具/venv | `/usmile/.espressif` ← 挂载自 `data/tools/espressif` |
| 工程 | `/usmile/workspace` ← 工程根目录下的 `workspace/` |

别名 `esp_idf` 通过 `~` 解析到 `/usmile`。

## 部署流水线

```
config.env
    │
    ▼
clone-idf.sh ──► data/sdk/esp/esp-idf-v6.0.2  (GitHub)
    │
build.sh ──────► 镜像 toolchains-hub:multi（仅 OS + SSH + 编译依赖）
    │
compose up ────► 挂载 data/ + workspace/ + 开放 SSH 端口
    │
install-tools.sh ► 容器内 ./install.sh ► 写回 data/tools/
```
