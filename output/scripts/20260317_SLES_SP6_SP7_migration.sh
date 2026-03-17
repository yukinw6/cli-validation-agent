#!/bin/bash
# ==============================================================================
# Script: SLES SP6 → SP7 マイグレーション実行
# 生成日: 2026-03-17
# 対象VM: instance-20260317-154124 / asia-northeast1-b / tech-trend-1762180118
# 接続方式: gcloud-ssh
# 元Runbook: output/runbooks/20260317_SLES_SP6_SP7_upgrade_precheck.md
# 実行レポート: output/runbooks/20260317_SLES_SP6_SP7_upgrade_precheck_exec_result.md
# ==============================================================================
# 注意事項:
#   - 実行前に GCP スナップショット（バックアップ）が READY であることを確認すること
#   - zypper migration は対話的コマンドのため、このスクリプトから呼び出さず
#     ターミナルから手動で実行すること（手順は STEP 4 のコメントを参照）
# ==============================================================================

set -euo pipefail

VM_NAME="instance-20260317-154124"
ZONE="asia-northeast1-b"
PROJECT_ID="tech-trend-1762180118"
LOG_DIR="$(cd "$(dirname "$0")/../../logs" && pwd)"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d)_SLES_SP6_SP7_migration_exec.log"
SNAPSHOT_NAME="${VM_NAME}-pre-migration-$(date +%Y%m%d-%H%M)"

SSH="gcloud compute ssh ${VM_NAME} --zone=${ZONE} --project=${PROJECT_ID} --"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

run_remote() {
  local label="$1"
  local cmd="$2"
  log "COMMAND: ${cmd}  # ${label}"
  ${SSH} "${cmd}" 2>&1 | tee -a "${LOG_FILE}"
  local status=${PIPESTATUS[0]}
  log "STATUS: $([ $status -eq 0 ] && echo SUCCESS || echo FAILED/EXIT=$status)"
  echo "---" | tee -a "${LOG_FILE}"
  return $status
}

# ------------------------------------------------------------------------------
# 初期化
# ------------------------------------------------------------------------------
mkdir -p "${LOG_DIR}"
log "=== SLES SP6 → SP7 マイグレーション実行スクリプト ==="
log "Target: ${VM_NAME} / ${ZONE} / ${PROJECT_ID}"

# ==============================================================================
# STEP 1: バックアップ（GCP スナップショット）
# ==============================================================================
log ""
log "=== STEP 1: GCP スナップショット取得 ==="

# ブートディスク名取得
DISK_NAME=$(gcloud compute instances describe "${VM_NAME}" \
  --zone="${ZONE}" --project="${PROJECT_ID}" \
  --format="value(disks[0].source.basename())")
log "ブートディスク名: ${DISK_NAME}"

# スナップショット取得
log "スナップショット取得中: ${SNAPSHOT_NAME}"
gcloud compute disks snapshot "${DISK_NAME}" \
  --zone="${ZONE}" --project="${PROJECT_ID}" \
  --snapshot-names="${SNAPSHOT_NAME}" 2>&1 | tee -a "${LOG_FILE}"

# 取得確認
SNAP_STATUS=$(gcloud compute snapshots describe "${SNAPSHOT_NAME}" \
  --project="${PROJECT_ID}" --format="value(status)")
log "スナップショットステータス: ${SNAP_STATUS}"

if [ "${SNAP_STATUS}" != "READY" ]; then
  log "ERROR: スナップショットが READY になりませんでした。続行しますか？ (yes/no)"
  read -r answer
  if [ "${answer}" != "yes" ]; then
    log "中断しました。"
    exit 1
  fi
fi

# ==============================================================================
# STEP 2: SP6 パッチ適用
# ==============================================================================
log ""
log "=== STEP 2: SP6 パッチ適用 ==="
run_remote "SP6パッチ適用" "sudo zypper -n patch"

log "パッチ適用後の再起動を実行します..."
${SSH} "sudo reboot" 2>/dev/null || true
log "再起動待機中（60秒）..."
sleep 60

# 起動確認
for i in $(seq 1 6); do
  log "VM起動確認 ${i}/6..."
  if ${SSH} "uptime" 2>/dev/null; then
    log "VM起動確認 OK"
    break
  fi
  sleep 10
done

# ==============================================================================
# STEP 3: 未登録モジュールの登録
# ==============================================================================
log ""
log "=== STEP 3: 未登録モジュール登録 ==="

MODULES=(
  "sle-module-confidential-computing/15.6/x86_64"
  "sle-module-containers/15.6/x86_64"
  "sle-module-live-patching/15.6/x86_64"
  "sle-module-public-cloud/15.6/x86_64"
  "sle-module-web-scripting/15.6/x86_64"
)

for MOD in "${MODULES[@]}"; do
  run_remote "モジュール登録: ${MOD}" "sudo SUSEConnect -p ${MOD}"
done

# ==============================================================================
# STEP 4: マイグレーションターゲット確認
# ==============================================================================
log ""
log "=== STEP 4: SP7 マイグレーションターゲット確認 ==="
run_remote "マイグレーション照会" "sudo zypper migration --query"

# ==============================================================================
# STEP 5: SP7 マイグレーション実行（手動）
# ==============================================================================
log ""
log "=== STEP 5: SP7 マイグレーション実行（手動） ==="
log ""
log "*** ここからは手動で実行してください ***"
log ""
log "以下のコマンドで対象VMにSSH接続し、マイグレーションを実行してください:"
log ""
log "  gcloud compute ssh ${VM_NAME} --zone=${ZONE} --project=${PROJECT_ID}"
log ""
log "接続後、VMで実行するコマンド:"
log ""
log "  sudo zypper migration"
log ""
log "  → ターゲット選択: SP7 (SLES 15 SP7) を選択"
log "  → ライセンス確認: 内容を確認の上 'yes' で進む"
log "  → 完了後: 再起動が促される場合は 'sudo reboot' を実行"
log ""
log "マイグレーション完了後、以下で SP7 を確認:"
log ""
log "  cat /etc/os-release"
log "  uname -r"
log ""
log "スナップショット名（ロールバック時に使用）: ${SNAPSHOT_NAME}"
