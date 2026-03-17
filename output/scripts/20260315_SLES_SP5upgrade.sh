#!/bin/bash
# =============================================================================
# Script: SLES SP5アップグレード前調査
# Generated: 2026-03-15
# Goal: SLES SP5アップグレード前の環境情報収集（読み取り専用）
# =============================================================================

set -euo pipefail

GOAL="SLES_SP5upgrade"
DATE=$(date +%Y%m%d)
LOG_DIR="$(cd "$(dirname "$0")/../.." && pwd)/logs"
LOG_FILE="${LOG_DIR}/${DATE}_${GOAL}.log"

mkdir -p "$LOG_DIR"

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

run_cmd() {
    local label="$1"
    local cmd="$2"
    local exit_code=0
    log ""
    log "=== [${label}] ==="
    eval "$cmd" 2>&1 | tee -a "$LOG_FILE" || exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
        log "[OK] ${label}"
    else
        log "[ERROR] ${label} failed (exit code: ${exit_code}). Skipping."
    fi
}

# ヘッダー
log "============================================="
log " CLI Validation Log"
log " Goal : SLES SP5アップグレード前調査"
log " Date : $(date '+%Y-%m-%d %H:%M:%S')"
log " Host : $(hostname)"
log "============================================="

# 1. OS情報
run_cmd "uname -a"            "uname -a"
run_cmd "cat /etc/os-release" "cat /etc/os-release"
run_cmd "hostname"            "hostname"

# 2. リポジトリ設定
run_cmd "zypper lr"           "zypper lr"

# 3. カーネルパッケージ情報
run_cmd "zypper info kernel-default" "zypper info kernel-default"

# 4. インストール済みパッケージ一覧
run_cmd "rpm -qa"             "rpm -qa"

# 5. サービス状態
run_cmd "systemctl status"    "systemctl status --no-pager"

# 6. ディスク使用状況
run_cmd "df -h"               "df -h"

# 7. ネットワーク状態
run_cmd "ip a"                "ip a"

# 8. 環境変数
run_cmd "env"                 "env"

# フッター
log ""
log "============================================="
log " 調査完了"
log " ログ出力先: ${LOG_FILE}"
log "============================================="
