.PHONY: help config build clone deploy deploy-quick install-tools stop status export-data logs ssh ssh-no-root

help:
	@echo "Toolchains Hub 常用命令:"
	@echo "  make config         # 从示例生成 config.env"
	@echo "  make clone          # 从 GitHub 拉取 ESP-IDF 6.0.2"
	@echo "  make build          # 仅构建 Docker 镜像"
	@echo "  make deploy         # 完整部署（clone + build + up + install-tools）"
	@echo "  make deploy-quick   # 快速部署（跳过 clone 与 tools）"
	@echo "  make install-tools  # 在容器内安装 ESP-IDF 6.0.2 工具链/venv"
	@echo "  make status         # 查看状态"
	@echo "  make logs           # 查看容器日志"
	@echo "  make stop           # 停止容器"
	@echo "  make ssh            # SSH 进容器（需已部署，会校正端口，需 sudo）"
	@echo "  make ssh-no-root    # SSH 进容器（沿用 config.env 端口，无需 sudo）"
	@echo "  make export-data    # 打包 data/ 便于迁移"

config:
	@test -f config.env || cp config.env.example config.env
	@echo "config.env ready — 请按目标机器修改端口等"

clone:
	./scripts/clone-idf.sh

build:
	./scripts/build.sh

deploy:
	./scripts/deploy.sh

deploy-no-build:
	./scripts/deploy.sh --skip-build

deploy-quick:
	./scripts/deploy.sh --skip-clone --skip-tools --skip-build

install-tools:
	./scripts/install-tools.sh

stop:
	./scripts/stop.sh

status:
	./scripts/status.sh

export-data:
	./scripts/export-data.sh

logs:
	./scripts/logs.sh

ssh:
	./scripts/ssh.sh

ssh-no-root:
	./scripts/ssh.sh --no-root
