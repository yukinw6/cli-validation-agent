#!/bin/bash
# ==============================================================================
# 調査スクリプト: SLES SP6→SP7 アップグレード前環境調査
# 対象: instance-20260330-094238 (asia-northeast1-b / tech-trend-1762180118)
# 生成日: 2026-03-30
# 種別: 読み取り専用（cli-validate フェーズ）
# ==============================================================================

set -euo pipefail

VM_NAME="instance-20260330-094238"
ZONE="asia-northeast1-b"
PROJECT_ID="tech-trend-1762180118"

wrap() {
  gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --project="${PROJECT_ID}" -- "$@"
}

echo "=== [1] OSバージョン ==="
wrap cat /etc/os-release

echo ""
echo "=== [2] カーネル・アーキテクチャ ==="
wrap "uname -r && uname -m"

echo ""
echo "=== [3] ディスク使用量 ==="
wrap df -h

echo ""
echo "=== [4] ブロックデバイス一覧 ==="
wrap lsblk

echo ""
echo "=== [5] SUSE登録状態 ==="
wrap sudo SUSEConnect --status

echo ""
echo "=== [6] マイグレーション可否確認 ==="
wrap sudo zypper migration --query || true

echo ""
echo "=== [7] 失敗サービス確認 ==="
wrap systemctl list-units --state=failed

echo ""
echo "=== [8] 未適用パッチ一覧 ==="
wrap sudo zypper lu

echo ""
echo "=== [9] ネットワークインターフェース ==="
wrap ip addr show

echo ""
echo "=== [10] SCC接続確認 ==="
wrap "curl -s --max-time 10 https://scc.suse.com/ -o /dev/null -w '%{http_code}'"

echo ""
echo "=== 調査完了 ==="
