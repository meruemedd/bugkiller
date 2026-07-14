.PHONY: setup pull dev pull-dev stop mobile logs optimize auto-fix start-fix watch-projects sync-projects pull-projects watch-dev discover-esim push-three help

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

help:
	@echo "BugKiller make targets:"
	@echo "  setup           npm install"
	@echo "  pull            git pull（仅本仓库）"
	@echo "  dev             启动本仓库 Web + API + Shared"
	@echo "  pull-dev        git pull + 启动"
	@echo "  stop            停止后台进程"
	@echo "  mobile          Android/iOS 构建安装指引"
	@echo "  discover-esim   发现本机 ESIM_B/ESIM_A/ESIM_I 并写入 projects.json"
	@echo "  watch-projects  常驻监听 ESIM 三项目：改动 commit/push + 定时 pull"
	@echo "  sync-projects   一轮：ESIM 三项目各自 commit → pull → push"
	@echo "  push-three      同 sync-projects（分别提交三项目到各自 GitHub）"
	@echo "  pull-projects   一轮：只 pull ESIM 三项目"
	@echo "  watch-dev       同步 + 启动本仓库并自动修复"
	@echo "  start-fix       启动本仓库服务 + 收集日志 + 自动修复"
	@echo "  auto-fix        仅根据 logs/ 自动修复并生成提案"
	@echo "  logs            收集日志到 logs/"
	@echo "  optimize        根据日志生成 proposals/（只提案）"
	@echo ""
	@echo "电脑端监听三项目: make discover-esim && make watch-projects"

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
	cd "$(ROOT)" && bash scripts/discover-esim.sh --write

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
