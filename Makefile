.PHONY: setup pull dev pull-dev stop mobile logs optimize auto-fix start-fix watch-projects sync-projects pull-projects watch-dev push-three help

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

help:
	@echo "BugKiller make targets:"
	@echo "  setup           npm install"
	@echo "  pull            git pull（仅本仓库）"
	@echo "  dev             启动 Web + API + Shared（纯本地，无需 GitHub）"
	@echo "  pull-dev        git pull + 启动"
	@echo "  stop            停止后台进程"
	@echo "  mobile          Android/iOS 构建安装指引"
	@echo "  watch-projects  常驻：多项目 git 同步（commit/push + pull）"
	@echo "  watch-dev       常驻：git 同步 + 启动本仓库并自动修复"
	@echo "  sync-projects   扫描一轮：commit → pull → push"
	@echo "  pull-projects   扫描一轮：只 pull 各配置项目（含本仓库）"
	@echo "  start-fix       启动本仓库服务 + 收集日志 + 自动修复"
	@echo "  auto-fix        仅根据 logs/ 自动修复并生成提案"
	@echo "  logs            收集日志到 logs/"
	@echo "  optimize        根据日志生成 proposals/（只提案）"
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

auto-fix:
	cd "$(ROOT)" && bash scripts/auto-fix.sh

start-fix:
	cd "$(ROOT)" && bash scripts/start-and-fix.sh

watch-projects:
	cd "$(ROOT)" && node scripts/watch-and-commit.mjs

watch-dev:
	cd "$(ROOT)" && node scripts/watch-and-commit.mjs --with-dev

sync-projects:
	cd "$(ROOT)" && node scripts/watch-and-commit.mjs --once

pull-projects:
	cd "$(ROOT)" && node scripts/watch-and-commit.mjs --pull-only
