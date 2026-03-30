#!/bin/bash
# 実行スクリプト: SLES SP6→SP7 アップグレード前準備
# 生成日: 2026-03-30
# 元Runbook: output/runbooks/20260330_SLES_SP6_SP7_upgrade_precheck.md
# 元実行レポート: output/runbooks/20260330_SLES_SP6_SP7_upgrade_precheck_exec_result.md
#
# 使い方: bash output/scripts/20260330_SLES_SP6_SP7_upgrade_precheck_exec.sh
# 注意: zypper migration（ステップ4）は手動実行が必要です。

set -euo pipefail

VM_NAME="instance-20260330-094238"
ZONE="asia-northeast1-b"
PROJECT_ID="tech-trend-1762180118"
SNAPSHOT_NAME="${VM_NAME}-pre-migration-$(date +%Y%m%d-%H%M)"

wrap() {
  gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --project="${PROJECT_ID}" -- "$@"
}

# [0-1] ブートディスク名取得
echo "[0-1] ブートディスク名を取得します..."
DISK_NAME=$(gcloud compute instances describe "${VM_NAME}" \
  --zone="${ZONE}" --project="${PROJECT_ID}" \
  --format="value(disks[0].source.basename())") || {
  echo "ERROR: [0-1] ブートディスク名取得が失敗しました。"; exit 1
}
echo "  ディスク名: ${DISK_NAME}"

# [0-2] スナップショット取得
echo "[0-2] スナップショットを取得します: ${SNAPSHOT_NAME}"
gcloud compute disks snapshot "${DISK_NAME}" \
  --zone="${ZONE}" --project="${PROJECT_ID}" \
  --snapshot-names="${SNAPSHOT_NAME}" || {
  echo "ERROR: [0-2] スナップショット取得が失敗しました。"; exit 1
}

# [0-3] スナップショット確認
echo "[0-3] スナップショットの状態を確認します..."
STATUS=$(gcloud compute snapshots describe "${SNAPSHOT_NAME}" \
  --project="${PROJECT_ID}" --format="value(status)")
echo "  ステータス: ${STATUS}"
if [ "${STATUS}" != "READY" ]; then
  echo "ERROR: スナップショットが READY になりませんでした（${STATUS}）。"
  read -r -p "バックアップなしで続行しますか？ (yes/no): " CONFIRM
  if [ "${CONFIRM}" != "yes" ]; then
    echo "中止します。"; exit 1
  fi
fi

# [1-1] SP6 パッチ適用
echo "[1-1] SP6 パッチを適用します..."
wrap sudo zypper --non-interactive patch || {
  echo "ERROR: [1-1] zypper patch が失敗しました。処理を中止します。"; exit 1
}

# [1-2] 再起動
echo "[1-2] 再起動します..."
wrap sudo reboot || true

echo "  再起動待機中（60秒）..."
sleep 60
echo "  SSH 接続を確認します..."
wrap uptime || { echo "ERROR: [1-2] 再起動後の SSH 接続に失敗しました。"; exit 1; }
echo "  VM 起動確認完了。"

# [2-1〜2-5] 未登録モジュール登録
echo "[2-1〜2-5] 未登録モジュールを登録します..."
for MODULE in \
  sle-module-public-cloud/15.6/x86_64 \
  sle-module-containers/15.6/x86_64 \
  sle-module-web-scripting/15.6/x86_64 \
  sle-module-live-patching/15.6/x86_64 \
  sle-module-confidential-computing/15.6/x86_64; do
  echo "  登録: ${MODULE}"
  wrap sudo SUSEConnect -p "${MODULE}" || {
    echo "ERROR: SUSEConnect -p ${MODULE} が失敗しました。処理を中止します。"; exit 1
  }
done

# [3-1] マイグレーションターゲット確認
echo "[3-1] マイグレーションターゲットを確認します..."
wrap sudo zypper migration --query || {
  echo "ERROR: [3-1] zypper migration --query が失敗しました。SP7パスが表示されているか確認してください。"; exit 1
}

# [4] zypper migration（手動実行）
echo ""
echo "=========================================="
echo "[4] SP7 マイグレーション実行は手動実行が必要です。"
echo "以下のコマンドを手動で実行してください:"
echo ""
echo "  gcloud compute ssh ${VM_NAME} \\"
echo "    --zone=${ZONE} --project=${PROJECT_ID} \\"
echo "    --ssh-flag=\"-tt\" -- sudo zypper migration"
echo ""
echo "マイグレーション完了後、再起動が必要な場合:"
echo ""
echo "  gcloud compute ssh ${VM_NAME} \\"
echo "    --zone=${ZONE} --project=${PROJECT_ID} \\"
echo "    -- sudo reboot"
echo "=========================================="
echo ""
read -r -p "手動実行が完了したら Enter を押してください..."

echo ""
echo "完了: 自動実行ステップ（0〜3）が終了しました。"
echo "スナップショット名: ${SNAPSHOT_NAME}"
