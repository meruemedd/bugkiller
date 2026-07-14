.PHONY: setup pull dev pull-dev stop mobile logs optimize help

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

help:
	@echo "BugKiller make targets:"
	@echo "  setup      npm install"
	@echo "  pull       git pull"
	@echo "  dev        启动 Web + API + Shared（纯本地，无需 GitHub）"
	@echo "  pull-dev   git pull + 启动"
	@echo "  stop       停止后台进程"
	@echo "  mobile     Android/iOS 构建安装指引"
	@echo "  logs       收集日志到 logs/"
	@echo "  optimize   根据日志生成 proposals/"
	@echo ""
	@echo "本地联调可跳过 GitHub，直接: make setup && make dev"

setup:
	cd "$(ROOT)" && npm install

pull:
	cd "$(ROOT)" && git pull --ff-only || git pull

dev:
	cd "$(ROOT)" && bash scripts/dev-all.sh

pull-dev:
	cd "$(ROOT)" && bash scripts/pull-and-dev.sh

stop:
	cd "$(ROOT)" && bash scripts/stop-all.sh

mobile:
	cd "$(ROOT)" && bash scripts/mobile-hint.sh all

logs:
	cd "$(ROOT)" && bash scripts/collect-logs.sh

optimize:
	cd "$(ROOT)" && bash scripts/optimize-from-logs.sh
