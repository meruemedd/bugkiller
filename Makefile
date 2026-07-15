.PHONY: setup pull dev pull-dev stop mobile logs optimize auto-fix start-fix watch-projects sync-projects pull-projects watch-dev discover-esim push-three collab start-esim stop-esim check-esim help

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

help:
	@echo "BugKiller × ESIM 协作:"
	@echo "  collab          电脑端一键协作（须在 Mac 本机终端运行）"
	@echo "  check-esim      检查本机 ESIM_A/B/I 路径是否存在"
	@echo "  discover-esim   发现 ESIM_B/A/I 并写 projects.json"
	@echo "  start-esim      启动三项目联调"
	@echo "  stop-esim       停止三项目进程"
	@echo "  push-three      一轮：三项目各自 commit + push 到 GitHub"
	@echo "  watch-projects  常驻：改动自动 commit/push + 定时 pull"
	@echo "  pull-projects   一轮：只 pull（拿手机端更新）"
	@echo ""
	@echo "本仓库脚手架:"
	@echo "  setup / dev / stop / logs / optimize / watch-dev / start-fix"
	@echo ""
	@echo "手机↔电脑: 手机 Working Copy push → 电脑 make collab → 本机改完自动 push → 手机 pull"

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

discover-esim:
	cd "$(ROOT)" && ESIM_ROOT="$${ESIM_ROOT:-/Users/air/Documents/code/ESIM}" bash scripts/discover-esim.sh --write

check-esim:
	cd "$(ROOT)" && bash scripts/check-esim-paths.sh

start-esim:
	cd "$(ROOT)" && bash scripts/start-esim-projects.sh --restart

stop-esim:
	cd "$(ROOT)" && bash scripts/stop-esim-projects.sh

collab:
	cd "$(ROOT)" && bash scripts/esim-collab.sh

watch-projects:
	cd "$(ROOT)" && node scripts/watch-and-commit.mjs

watch-dev:
	cd "$(ROOT)" && node scripts/watch-and-commit.mjs --with-dev

sync-projects:
	cd "$(ROOT)" && node scripts/watch-and-commit.mjs --once

pull-projects:
	cd "$(ROOT)" && node scripts/watch-and-commit.mjs --pull-only

push-three:
	cd "$(ROOT)" && bash scripts/push-three-projects.sh
