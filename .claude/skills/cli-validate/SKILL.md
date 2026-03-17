---
name: cli-validate
description: CLIコマンドを計画・実行・分析し、RunbookとBashスクリプトを自動生成する。OS調査・サービス調査・環境確認などに使う。
---
# /cli-validate

## 説明
CLIコマンドを計画・実行・分析し、RunbookとBashスクリプトを自動生成する。

## 使い方

```
/cli-validate
target: <接続先ホスト名・IPアドレス・リソース識別子（省略時はローカル）>
connection_mode: <接続方式（省略時はローカル）>
goal: <調査目的>
```

### connection_mode の指定例

| 接続方式 | connection_mode の値 | ラッパーコマンド形式 |
|---------|---------------------|-------------------|
| ローカル実行 | （省略） | コマンドをそのまま実行 |
| SSH | `ssh` | `ssh <target> -- <command>` |
| GCP VM | `gcloud-ssh` | `gcloud compute ssh <vm_name> --zone=<zone> --project=<project_id> -- <command>` |
| Kubernetes Pod | `kubectl-exec` | `kubectl exec -it <pod_name> -n <namespace> -- <command>` |

### 使用例

ローカル環境調査:
```
/cli-validate
goal: ローカルのPython環境調査
```

GCP VM調査（SLES SPアップグレード前確認）:
```
/cli-validate
target: vm_name=instance-20260315-134204 zone=asia-northeast1-b project_id=tech-trend-1762180118
connection_mode: gcloud-ssh
goal: SLES SP4からSP6へのアップグレード前環境調査
```

SSH経由調査:
```
/cli-validate
target: 192.168.1.10
connection_mode: ssh
goal: Webサーバーのサービス状態調査
```

---

## Goal 分解ルール

Goalは以下の観点に分解して調査する。Goalの内容に応じて適切な観点を選択・追加する。

### 共通観点
- OS情報（バージョン・カーネル・アーキテクチャ）
- ディスク状態（使用量・マウント）
- ネットワーク状態（インターフェース・接続確認）
- サービス状態（主要サービスの稼働確認）

### OS調査（Linux）
- パッケージ情報（インストール済みパッケージ一覧）
- リポジトリ設定
- ユーザー・グループ情報

### SLES/SUSEアップグレード前確認（追加観点）
- SPマイグレーション状態（`zypper migration --query`）
- SUSE登録状態（`SUSEConnect --status`）
- ブートディスク名（バックアップ取得に必要）

### サービス調査
- プロセス一覧・リソース使用状況
- ログ出力（直近のエラー）
- 設定ファイルの読み取り

不足情報がある場合はSafe commandsで取得する。

---

## 実行手順

### 実行モード判定

`connection_mode` が指定されている場合は**リモート実行モード**で動作する。
各コマンドは `connection_mode` に応じたラッパーでラップして実行する。

`connection_mode` が省略された場合はローカル実行モードで動作する。

---

### Step 1: コマンドプラン作成（Builder）

Goalを分析し、必要なSafe commandsのリストを作成する。
各コマンドに目的を添えること。

---

### Step 2: Safetyチェック（Reviewer）

プランに含まれる全コマンドがSafe commandsリストに含まれることを確認する。
1件でも禁止コマンドが含まれていればプランを差し戻す。

---

### Step 3: コマンド実行・ログ収集（Builder）

承認されたコマンドをBashツールで1件ずつ実際に実行する。
実行結果（stdout/stderr）をそのまま取得し、logs/YYYYMMDD_<goal>.log に記録する。
コマンドを実行せずにRunbookを生成してはならない。
実行結果が存在しない場合はStep 4に進まない。

---

### Step 4: 出力解析・コマンド改訂（Builder）

実行結果を解析する。
分析結果は必ず以下に分類する。

- Confirmed facts
- Assumptions
- Missing evidence

追加調査が必要な場合はコマンドをプランに追加する。
最大15イテレーション。

---

### Step 5: Runbook生成（Builder）

以下を確認できた場合にRunbook生成を行う。

- OS version
- 主要サービス・リソース状態
- 調査目的に必要な情報が揃っている
- major command errors resolved or documented

output/runbooks/YYYYMMDD_<goal>.md を生成する。
生成後、必ず人間に確認を求めること。

---

### Step 6: スクリプト生成（Builder）

人間がRunbookを承認したら
output/scripts/YYYYMMDD_<goal>.sh を生成する。

**このスクリプトは調査フェーズ（cli-validate）で実行した読み取り専用コマンドを再現するもの。**
**実行手順（Runbook の `## 手順` セクション）のスクリプトは cli-execute が生成する。**

---

## Runbook テンプレート

# Runbook: <Goal>
作成日: YYYY-MM-DD

## 調査環境
- ホスト名:
- OS:
- カーネル:
- 接続方式: ローカル / SSH / gcloud-ssh / kubectl-exec
- 接続先:

## Confirmed Facts

## Assumptions

## Missing Evidence

## 調査結果サマリー

## 手順

## バックアップ・ロールバック手順（任意）

> バックアップが取得済みの場合のみ記載する。バックアップ手順はドメインに依存するため、
> cli-execute/SKILL.md のドメインプロファイルを参照すること。

### バックアップ情報

| 項目 | 値 |
|------|----|
| バックアップ名 | （cli-execute 実行後に記入） |
| 対象リソース | |
| 取得ステータス | READY / FAILED / 未実施 |
| 取得日時 | |

### ロールバック手順

（ドメインプロファイルに従い記載する）

## 注意事項
