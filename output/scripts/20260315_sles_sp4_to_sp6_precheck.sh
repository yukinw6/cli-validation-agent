#!/bin/bash
# =============================================================================
# SLES SP4からSP6へのアップグレード前環境調査スクリプト
# 作成日: 2026-03-15
# 対象VM: instance-20260315-151733 (asia-northeast1-a / tech-trend-1762180118)
#
# 注意: このスクリプトは読み取り専用の調査コマンドのみ実行します。
#       破壊的操作・状態変更操作は一切含みません。
# =============================================================================

set -euo pipefail

# --- 設定 ---
PROJECT_ID="${PROJECT_ID:-tech-trend-1762180118}"
ZONE="${ZONE:-asia-northeast1-a}"
VM_NAME="${VM_NAME:-instance-20260315-151733}"
DATE=$(date +%Y%m%d)
LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/${DATE}_sles_sp4_to_sp6_precheck.log"

# --- ヘルパー関数 ---
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

run_remote() {
    local label="$1"
    local cmd="$2"
    log ""
    log "=== ${label} ==="
    if gcloud compute ssh "${VM_NAME}" \
        --zone="${ZONE}" \
        --project="${PROJECT_ID}" \
        -- ${cmd} 2>&1 | tee -a "$LOG_FILE"; then
        log "[OK] ${label}"
    else
        log "[WARN] ${label} exited with non-zero status (recorded and continuing)"
    fi
}

# --- 初期化 ---
mkdir -p "$LOG_DIR"
log "=============================================="
log "CLI Validation: SLES SP4→SP6 アップグレード前調査"
log "Date      : $(date)"
log "Project   : ${PROJECT_ID}"
log "Zone      : ${ZONE}"
log "VM        : ${VM_NAME}"
log "=============================================="

# --- 接続確認 ---
log ""
log "=== [0] gcloud 接続確認 ==="
gcloud compute instances describe "${VM_NAME}" \
    --zone="${ZONE}" \
    --project="${PROJECT_ID}" \
    --format="value(status)" 2>&1 | tee -a "$LOG_FILE"

# --- OS情報 ---
run_remote "[1] hostname"              "hostname"
run_remote "[2] uname -a"              "uname -a"
run_remote "[3] cat /etc/os-release"   "cat /etc/os-release"

# --- SUSE登録状態 ---
run_remote "[4] SUSEConnect --status (sudo)" "sudo SUSEConnect --status"

# --- リポジトリ情報 ---
run_remote "[5] zypper lr"             "zypper lr"
run_remote "[6] zypper lr -u"          "zypper lr -u"
run_remote "[7] ls /etc/zypp/repos.d/" "ls /etc/zypp/repos.d/"

# --- マイグレーション状態 ---
# 注意: zypper migration --query は TTY が必要なため非対話 SSH では exit 1 になる場合がある
# エラーは記録してスキップ
log ""
log "=== [8] zypper migration --query ==="
log "[INFO] TTY が必要なコマンドのため、非対話 SSH では失敗する場合があります"
gcloud compute ssh "${VM_NAME}" \
    --zone="${ZONE}" \
    --project="${PROJECT_ID}" \
    -- "sudo zypper migration --query" 2>&1 | tee -a "$LOG_FILE" || \
    log "[WARN] zypper migration --query failed (TTY required — run interactively)"

# --- パッケージ情報 ---
run_remote "[9] rpm -qa"               "rpm -qa"

# --- サービス状態 ---
run_remote "[10] systemctl status --no-pager" "systemctl status --no-pager"

# --- ディスク状態 ---
run_remote "[11] df -h"                "df -h"

# --- ネットワーク情報 ---
run_remote "[12] ip a"                 "ip a"

# --- 完了 ---
log ""
log "=============================================="
log "調査完了"
log "ログ出力先: ${LOG_FILE}"
log "=============================================="
log ""
log "[次のアクション]"
log "1. zypper migration --query の結果を TTY 上で確認してください:"
log "   gcloud compute ssh ${VM_NAME} --zone=${ZONE} --project=${PROJECT_ID}"
log "   VM内: sudo zypper migration --query"
log ""
log "2. sle-ha (HA Extension) が登録済みのためクラスタ状態を確認してください"
