# Toolchains Hub — 可迁移 Docker 开发环境

只装 **ESP-IDF 6.0.2**（GitHub 官方正式版）。  
换机器时拷贝本目录（或再加打包的 `data/`），改好 `config.env` 后一键部署即可。

## 架构

```
本工程 (toolchains-hub)
├── Dockerfile / docker-compose.yml     # 镜像与编排
├── config.env                          # 本机配置（端口等）
├── scripts/                            # build / deploy / clone / install
├── data/                               # 运行时数据
│   ├── sdk/esp/esp-idf-v6.0.2          # GitHub espressif/esp-idf
│   └── tools/                          # 工具链 + venv（gitignore）
└── workspace/                          # 开发工程（与 data 同级，内容 gitignore）

容器 HOME 固定为 /toolchain
SSH: 宿主机 3022 起自动选空闲端口 -> 容器 22
```

镜像**不**内嵌 IDF 源码；源码始终是 git 仓库。

## 环境要求

- Docker + Docker Compose v2
- 能访问 GitHub（`https://github.com/espressif/esp-idf.git`）
- 首次 `install-tools` 需能访问 Espressif 工具下载源（或已有可迁移的 `data/tools`）

## 快速开始（新机器）

```bash
# 1. 拷贝本目录到目标机器后进入
cd toolchains-hub

# 2. 生成并编辑配置
make config
vim config.env
# 重点检查：
#   - SSH_HOST_PORT / SSH_PASSWORD
#   - IDF_INSTALL_TARGETS（芯片）
#   - IDF_REF（默认 v6.0.2）

# 3. 一键部署：clone GitHub IDF + 构建镜像 + 启动 + 装工具
make deploy
```

完成后：

```bash
make ssh
esp_idf
idf_status
cd ~/workspace && idf.py --version
```

## 常用命令

| 命令 | 作用 |
|------|------|
| `make config` | 生成 `config.env` |
| `make clone` | 从 GitHub 拉取/更新 ESP-IDF 6.0.2 |
| `make build` | 只构建 Docker 镜像 |
| `make deploy` | 完整部署 |
| `make deploy-quick` | 跳过 clone/build/tools，仅重启容器 |
| `make install-tools` | 容器内安装工具链 |
| `make status` | 查看仓库与工具状态 |
| `make logs` | 容器日志 |
| `make stop` | 停止容器 |
| `make export-data` | 打包 `data/`（不含 workspace） |
| `make ssh` | SSH 进入容器（会校正端口，可能需要 sudo） |
| `make ssh-no-root` | SSH 进入容器（沿用 config.env 端口） |

## 配置说明（config.env）

| 变量 | 含义 | 默认 |
|------|------|------|
| `DOCKER_USE_SUDO` | 仅 Docker 命令使用 sudo | `true` |
| `CONTAINER_NAME` | 容器名；留空时按宿主机用户名生成 | 空 = `toolchains-hub-$USER` |
| `SSH_HOST_PORT` | 宿主机 SSH 端口；留空或被占用时自动选择并写回 | 空 = 自动 |
| `SSH_HOST_PORT_START` | 自动选择端口的起始值 | `3022` |
| `CONTAINER_USER` | 容器 SSH 用户 | `toolchain` |
| `CONTAINER_HOME` | 容器 HOME | `/toolchain` |
| `SSH_PASSWORD` | SSH 密码（root 同步设置） | `toolchain168` |
| `IDF_DATA_ROOT` | 数据根目录 | 空 = `./data` |
| `IDF_WORKSPACE` | 工程映射目录 | 空 = `./workspace` |
| `IDF_URL` | ESP-IDF 仓库 | `https://github.com/espressif/esp-idf.git` |
| `IDF_REF` | 分支或 tag | `v6.0.2` |
| `INSTALL_TOOLS` | 部署时是否装工具 | `true` |
| `IDF_INSTALL_TARGETS` | `install.sh` 目标 | `all` |
| `MOUNT_HOST_SSH` | 是否只读挂载宿主机 `~/.ssh` | `true` |

镜像名默认 `toolchains-hub:multi`。改密码后需重新 `make build` 再 `deploy`。

## 迁移到另一台机器

### 方式 A：只带工程，新机器重新拉仓库 + 装工具

1. 拷贝本工程目录（可不含 `data/sdk` 与 `data/tools`）
2. `make config` → 按需改 `config.env`
3. `make deploy`

### 方式 B：连同 tools 一起带走（省去重新下载工具链）

在源机器：

```bash
make export-data
# 得到 toolchains-hub-data-YYYYMMDD.tar.gz
```

在目标机器：

```bash
# 1. 拷贝整个工程目录 + tar 包
cd toolchains-hub
tar -xzf toolchains-hub-data-YYYYMMDD.tar.gz

make config
./scripts/deploy.sh --skip-tools
# 若 sdk 也在包内，可再加 --skip-clone
```

`workspace/` 与 `data/` 同级，不在 tar 包内；拷贝整个工程目录即可带走工程。

> 工具链/venv 是在容器（Ubuntu 22.04 + Python 3.10，`HOME=/toolchain`）里生成的。  
> 目标机器用同一镜像定义部署即可复用。

## 容器内开发

```bash
make ssh
esp_idf
cd ~/workspace/your_project
idf.py set-target esp32s3
idf.py build
```

宿主机 `workspace/` 映射为容器内 `~/workspace`。

## 烧录串口（可选）

编辑 `docker-compose.yml`，取消注释：

```yaml
privileged: true
devices:
  - /dev/ttyUSB0:/dev/ttyUSB0
```

然后：

```bash
./scripts/deploy.sh --skip-clone --skip-tools --force-recreate
```

## 目录一览

```
.
├── Dockerfile
├── docker-compose.yml
├── docker-compose.ssh.yml
├── Makefile
├── config.env.example
├── README.md
├── docs/DESIGN.md
├── scripts/
├── rootfs/
├── data/                 # SDK + 工具链
└── workspace/            # 开发工程（与 data 同级）
```

## 故障排查

| 现象 | 处理 |
|------|------|
| 构建时报 Docker Hub **i/o timeout** | `config.env` 里设国内 `BASE_IMAGE` 后重跑 `make build` |
| clone 失败 | 检查能否访问 GitHub；可改用代理或镜像 |
| clone 报 `upload-pack: not our ref` | 是 GitHub 拒绝按历史 SHA 拉子模块。脚本已改为只更新当前版本的子模块；重新 `make clone` 即可 |
| `esp_idf` 报找不到 export.sh | 先 `make clone` / `make status` 确认仓库在 `data/sdk/esp` |
| `idf.py` 找不到 / Python 报错 | `make install-tools` |
| SSH 连不上 | `make logs`；检查端口占用与 `SSH_HOST_PORT` |
| 改了密码不生效 | 密码在 **build** 时写入镜像，需 `make build` 后重建容器 |
| 容器内改不了 `workspace` | 重建容器：`./scripts/deploy.sh --force-recreate`。若仍有旧 root 文件：宿主机执行 `sudo chown -R "$(id -u):$(id -g)" workspace` |
