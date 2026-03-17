---
name: cli-execute
description: Runbookに基づきコマンドを実行し、実行ログとレポートを生成する。cli-validateで生成したRunbookの承認後に使う。
---
# /cli-execute

## 説明
承認済みRunbookに基づきコマンドを順次実行し、実行ログと実行レポートを生成する。
`cli-validate` で生成・承認されたRunbookが前提。実行前に必ず人間の最終確認を得る。

## 使い方

```
/cli-execute
target: <接続先ホスト名・IPアドレス・リソース識別子（省略時はローカル）>
connection_mode: <接続方式（省略時はローカル）>
profile: <ドメインプロファイル名（省略時はなし）>
runbook: <output/runbooks/YYYYMMDD_xxx.md のパス>   # 必須
```

`profile` に指定できる値:

| profile 値 | プロファイルファイル | 主なユースケース |
|-----------|-------------------|----------------|
| （省略） | なし | ローカル・汎用Linux |
| `sles-gcp` | `profiles/sles-gcp.md` | SLES VM on GCP（SPマイグレーション等） |

### connection_mode の指定例

| 接続方式 | connection_mode の値 | ラッパーコマンド形式 |
|---------|---------------------|-------------------|
| ローカル実行 | （省略） | コマンドをそのまま実行 |
| SSH | `ssh` | `ssh <target> -- <command>` |
| GCP VM | `gcloud-ssh` | `gcloud compute ssh <vm_name> --zone=<zone> --project=<project_id> --ssh-flag="-tt" -- <command>` |
| Kubernetes Pod | `kubectl-exec` | `kubectl exec -it <pod_name> -n <namespace> -- <command>` |

### 使用例

```
/cli-execute
target: vm_name=instance-20260315-134204 zone=asia-northeast1-b project_id=tech-trend-1762180118
connection_mode: gcloud-ssh
profile: sles-gcp
runbook: output/runbooks/20260315_SLES_SP4_to_SP6_upgrade_precheck.md
```

---

## 実行手順

### Step 1: Runbook 読み込み（Executor）

指定された Runbook を読み込み、`## 手順` セクションからコマンド一覧を抽出する。

---

### Step 2: Safetyチェック（Reviewer）

**プロファイル読み込み**: `profile` が指定されている場合、対応するプロファイルファイル（`profiles/<profile>.md`）を読み込み、「追加許可コマンド」と「追加禁止コマンド」をこのステップの照合に加える。

抽出したコマンドが以下の **cli-execute 実行許可コマンド** に含まれることを確認する。

#### 基本許可コマンド（全ドメイン共通）

```
# システム情報
uname -a
cat /etc/os-release
hostname
uptime
id

# プロセス・リソース
ps aux
top -bn1
free -h
df -h

# ネットワーク
ip addr
ip route
ss -tlnp
ping -c 4

# ログ・設定読み取り
journalctl
dmesg
cat （読み取りのみ）
less / more / head / tail

# サービス状態確認（読み取りのみ）
systemctl status
systemctl list-units

# 再起動（ドメインで明示的に許可された場合のみ）
sudo reboot
```

#### ドメイン追加コマンド（ドメインプロファイルで定義）

ドメインプロファイルに応じて以下のカテゴリのコマンドを追加許可できる。
詳細は各プロファイルを参照すること。

**SLES/SUSEドメイン** → [`profiles/sles-gcp.md`](profiles/sles-gcp.md) 参照

**AWS EC2ドメイン**（将来追加予定）:
```
aws ec2 describe-instances
aws ec2 create-snapshot
aws ec2 stop-instances
aws ec2 start-instances
```

**Kubernetesドメイン**（将来追加予定）:
```
kubectl get
kubectl describe
kubectl logs
```

照合はコマンドの先頭サブコマンドのプレフィックス一致で行う。
1件でも許可リスト外のコマンドが含まれていれば**実行を中止**し、ユーザーに報告する。

---

### Step 2A: バックアップ取得（Executor）- 任意

バックアップ手順はドメインに依存する。Runbookの `## バックアップ・ロールバック手順` セクションに
バックアップ手順が記載されている場合のみ実行する。

**バックアップが記載されていない場合**: このステップをスキップする。

**バックアップが記載されている場合**:
1. Runbookに記載されたバックアップコマンドを実行する
2. バックアップの成功を確認する
3. **失敗時**: ユーザーに「バックアップなしで続行するか」を確認する。"yes" の明示的な回答なしには次のステップへ進まない。

#### SLES+GCPドメインのバックアップ例

```
# ブートディスク名取得
gcloud compute instances describe <vm_name> --zone=<zone> --project=<project_id> \
  --format="value(disks[0].source.basename())"

# スナップショット取得
# 命名規則: <vm_name>-pre-migration-<YYYYMMDD>-<HHmm>
gcloud compute disks snapshot <disk_name> --zone=<zone> --project=<project_id> \
  --snapshot-names=<snapshot_name>

# 取得確認（READY であれば成功）
gcloud compute snapshots describe <snapshot_name> --project=<project_id> \
  --format="value(status)"
```

---

### Step 3: 人間への最終確認

実行するコマンド一覧を提示し、明示的な承認を得る。

表示形式:
```
以下のコマンドを実行します。承認しますか？ (yes/no)

[1] <コマンド1>  # <目的>
[2] <コマンド2>  # <目的>
...
```

**"yes" の明示的な回答なしに実行してはならない。**

---

### Step 4: 実行・ログ収集（Executor）

承認後、コマンドを1件ずつ実行する。

#### リモート実行モード（connection_mode が指定された場合）

各コマンドは `connection_mode` に応じたラッパーでラップして実行する。

#### ローカル実行モード

コマンドをそのままBashで実行する。

#### ログ記録

実行ログを `logs/YYYYMMDD_<goal>_exec.log` に記録する。各エントリの形式:

```
[YYYY-MM-DD HH:MM:SS] COMMAND: <コマンド>
[YYYY-MM-DD HH:MM:SS] STATUS: SUCCESS / FAILED
[YYYY-MM-DD HH:MM:SS] OUTPUT:
<stdout/stderr>
---
```

---

### Step 5: 結果解析（Executor）

各コマンドの実行結果を分類する。

- **SUCCESS**: 終了コード 0
- **FAILED**: 終了コード非0（エラー内容を記録し、次のコマンドへ進む）

同一コマンドのリトライは最大2回まで。3回目は FAILED として記録しスキップする。

---

### Step 6: 実行レポート生成（Executor）

`output/runbooks/YYYYMMDD_<goal>_exec_result.md` を生成する。

---

### Step 7: スクリプト生成（Executor）

実行レポート生成後、自動で `output/scripts/YYYYMMDD_<goal>_exec.sh` を生成する。

**スクリプトの内容:**
- Runbook の `## 手順` セクションから抽出した全コマンドを順番に記載
- バックアップステップ（スナップショット取得等）も含む
- **手動実行が必要なコマンド**（対話的コマンド等）は実行せず、`echo` でユーザーへの指示メッセージを出力して終了するブロックとして記載
- 各ステップにエラー時の `exit 1` を含む

**手動実行判定の基準:**
- プロファイルの許可コマンドコメントに「手動実行推奨」「対話的」等の注記があるもの
- 実行時に `FAILED` になった後に手動対応が必要と判断したもの

**スクリプトテンプレート:**

```bash
#!/bin/bash
# 実行スクリプト: <Goal>
# 生成日: YYYY-MM-DD
# 元Runbook: <runbookパス>
# 元実行レポート: <exec_result パス>
#
# 使い方: bash <このスクリプト名>.sh
# 注意: 手動実行が必要なステップは echo で案内します。

set -euo pipefail

# [1] <ステップ名>
echo "[1] <ステップ名> を実行します..."
<コマンド> || { echo "ERROR: [1] <ステップ名> が失敗しました。処理を中止します。"; exit 1; }

# [N] <手動実行が必要なステップ>（例: zypper migration）
echo ""
echo "=========================================="
echo "[N] <ステップ名> は手動実行が必要です。"
echo "以下のコマンドを手動で実行してください:"
echo ""
echo "  <コマンド>"
echo ""
echo "完了後、このスクリプトの次のステップを続けてください。"
echo "=========================================="
echo ""
read -r -p "手動実行が完了したら Enter を押してください..."

echo "完了: 全ステップが終了しました。"
```

---

## 実行レポート テンプレート

```markdown
# 実行レポート: <Goal>
作成日: YYYY-MM-DD
元Runbook: <runbookパス>

## 実行環境
- ホスト名:
- OS:
- 接続方式: ローカル / SSH / gcloud-ssh / kubectl-exec
- 接続先:

## バックアップ情報（取得した場合）

| 項目 | 値 |
|------|----|
| バックアップ名 | |
| 対象リソース | |
| 取得ステータス | READY / FAILED / 未実施 |
| 取得日時 | |

### ロールバック手順（失敗時）

（Runbookのバックアップ・ロールバック手順セクションを参照）

## 実行サマリー

| # | コマンド | ステータス | 備考 |
|---|---------|-----------|------|
| 1 | ...     | SUCCESS   |      |
| 2 | ...     | FAILED    | エラー詳細 |

## 実行結果詳細

### [1] <コマンド>
**ステータス**: SUCCESS / FAILED
**出力**:
\```
<stdout/stderr>
\```

## エラー・注意事項

## 次のアクション
```

---

## 出力先

| 種別 | パス |
|------|------|
| 実行ログ | `logs/YYYYMMDD_<goal>_exec.log` |
| 実行レポート | `output/runbooks/YYYYMMDD_<goal>_exec_result.md` |
| 実行スクリプト | `output/scripts/YYYYMMDD_<goal>_exec.sh` |
