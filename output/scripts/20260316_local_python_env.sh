#!/usr/bin/env bash
# ============================================================
# Script: ローカルのPython環境調査
# Generated: 2026-03-16
# Runbook: output/runbooks/20260316_local_python_env.md
# Mode: ローカル実行
# ============================================================

set -euo pipefail

LOG_FILE="logs/20260316_local_python_env.log"
mkdir -p logs

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

run() {
  local cmd="$*"
  log "COMMAND: $cmd"
  if output=$(eval "$cmd" 2>&1); then
    log "STATUS: SUCCESS"
  else
    log "STATUS: FAILED (exit code: $?)"
  fi
  log "OUTPUT:"
  echo "$output" | tee -a "$LOG_FILE"
  echo "---" | tee -a "$LOG_FILE"
}

log "GOAL: ローカルのPython環境調査"
log "MODE: ローカル実行"

# 1. OS情報
run uname -a
run cat /etc/os-release

# 2. Pythonバージョン確認
run python3 --version
run python --version || true   # Python2は存在しない場合があるためエラーを無視

# 3. インタープリタパス
run which python3
run ls /usr/bin/python\*

# 4. pip確認
run pip3 --version

# 5. インストール済みパッケージ一覧
run pip3 list

# 6. venv利用可否
run python3 -m venv --help

log "調査完了。Runbook: output/runbooks/20260316_local_python_env.md"
