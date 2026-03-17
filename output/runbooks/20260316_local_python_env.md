# Runbook: ローカルのPython環境調査
作成日: 2026-03-16

## 調査環境
- ホスト名: NucBoxk11
- OS: Ubuntu 24.04.4 LTS (Noble Numbat)
- カーネル: 6.6.87.2-microsoft-standard-WSL2
- 接続方式: ローカル
- 接続先: （ローカル実行）

## Confirmed Facts

- Python3: 3.12.3（`/usr/bin/python3`）
- Python2: インストールなし（`python` コマンド不在）
- pip3: 24.0（`/usr/lib/python3/dist-packages/pip`）
- venv: 利用可能（`python3 -m venv`）
- インストール済みパッケージ: 59件（すべてシステムパッケージ）
- ユーザー仮想環境（venv/pyenv）: なし

## Assumptions

- システムパッケージのみのため、ユーザープロジェクト用の独立した環境はまだ作成されていない

## Missing Evidence

- なし（調査目的を満たす情報はすべて取得済み）

## 調査結果サマリー

WSL2上のUbuntu 24.04にPython 3.12.3がシステムパッケージとしてインストールされている。
pip・venvは利用可能。pyenv・ユーザー仮想環境は未作成の状態。
プロジェクト開発を始める場合は `python3 -m venv` で仮想環境を作成することを推奨。

## 手順

### 1. Pythonバージョン確認
```bash
python3 --version
# => Python 3.12.3
```

### 2. インタープリタパス確認
```bash
which python3
# => /usr/bin/python3
```

### 3. pip確認
```bash
pip3 --version
# => pip 24.0 from /usr/lib/python3/dist-packages/pip (python 3.12)
```

### 4. インストール済みパッケージ一覧
```bash
pip3 list
```

主要パッケージ（抜粋）:
| パッケージ | バージョン |
|-----------|-----------|
| requests | 2.31.0 |
| PyYAML | 6.0.1 |
| cryptography | 41.0.7 |
| Jinja2 | 3.1.2 |
| rich | 13.7.1 |
| setuptools | 68.1.2 |
| pip | 24.0 |

### 5. 仮想環境作成（必要時）
```bash
python3 -m venv .venv
source .venv/bin/activate
```

## バックアップ・ロールバック手順（任意）

該当なし（読み取り専用調査のため）

## 注意事項

- `python` コマンドは存在しない。`python3` を使うこと
- システムパッケージを `pip3 install` で直接変更しないこと（venv推奨）
