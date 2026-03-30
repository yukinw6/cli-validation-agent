#!/bin/bash
# Runbook: ローカル環境の基本情報調査
# 作成日: 2026-03-27
# 目的: ローカル環境の基本情報（OS・メモリ・ディスク・ネットワーク・サービス）を調査する

set -euo pipefail

echo "=== OS情報 ==="
uname -a
cat /etc/os-release

echo "=== ホスト名・稼働時間 ==="
hostname
uptime

echo "=== メモリ ==="
free -h

echo "=== ディスク ==="
df -h

echo "=== ネットワーク ==="
ip a

echo "=== 稼働サービス ==="
systemctl list-units --type=service --state=running --no-pager
