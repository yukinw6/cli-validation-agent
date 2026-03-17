# Runbook: SLES SP4からSP6へのアップグレード前環境調査
作成日: 2026-03-15

## 調査環境
- **ホスト名**: instance-20260315-151733
- **OS**: SUSE Linux Enterprise Server for SAP Applications 15 SP4 (VARIANT: sles-sap)
- **カーネル**: 5.14.21-150400.24.187-default #1 SMP PREEMPT_DYNAMIC (2025-11-29) x86_64
- **GCPゾーン**: asia-northeast1-a
- **プロジェクト**: tech-trend-1762180118

---

## Confirmed Facts

| 項目 | 詳細 |
|------|------|
| OS バージョン | SLES_SAP 15 SP4 (VERSION_ID="15.4") |
| SUSE 登録状態 | 全12製品/モジュールが `Registered` (SP4) |
| リポジトリ形式 | `plugin:/susecloud` (SUSE Public Cloud Update Infrastructure) |
| ディスク `/` | 10G 中 2.4G 使用 (24%) — 空き 7.7G |
| ディスク `/boot/efi` | 20M 中 3.0M 使用 (15%) |
| systemd 状態 | State: running / Failed: 0 units |
| ネットワーク | eth0: 10.146.0.7/32 (GCP内部IP) |

### 登録済みモジュール一覧 (SUSEConnect --status)
| 製品/モジュール | バージョン | 状態 |
|----------------|-----------|------|
| SLES_SAP | 15.4 | Registered |
| sle-ha | 15.4 | Registered |
| sle-module-basesystem | 15.4 | Registered |
| sle-module-containers | 15.4 | Registered |
| sle-module-desktop-applications | 15.4 | Registered |
| sle-module-development-tools | 15.4 | Registered |
| sle-module-live-patching | 15.4 | Registered |
| sle-module-public-cloud | 15.4 | Registered |
| sle-module-python3 | 15.4 | Registered |
| sle-module-sap-applications | 15.4 | Registered |
| sle-module-server-applications | 15.4 | Registered |
| sle-module-web-scripting | 15.4 | Registered |

---

## Assumptions

- susecloud plugin 使用のため、SUSE Public Cloud Update Infrastructure 経由で SP6 へのマイグレーションパスが提供されると想定（実証済み）
- SP4→SP6 の直接マイグレーションには `zypper migration` コマンドで対象バージョンを選択する

---

## Missing Evidence

なし（全項目取得完了）

---

## zypper migration --query 結果

`--ssh-flag="-tt"` で TTY を強制割り当てして取得成功。利用可能なマイグレーションターゲット：

| # | ターゲット | 全モジュール対応 |
|---|-----------|----------------|
| 1 | SLES for SAP Applications **15 SP7** x86_64 | ○ (12モジュール) |
| 2 | SLES for SAP Applications **15 SP6** x86_64 | ○ (12モジュール) |
| 3 | SLES for SAP Applications **15 SP5** x86_64 | ○ (12モジュール) |

- **SP4→SP6 の直接マイグレーションパスが確認済み**
- 現在の updatestack は最新 (0 patches pending)
- 全リポジトリが最新状態

## HA クラスタ状態 (crm status)

```
crm_mon: Error: cluster is not available on this node (rc=102)
```

- `sle-ha` モジュールは登録済みだが、**このノードでは Pacemaker クラスタは構成・稼働していない**
- クラスタ停止状態またはシングルノード構成と判断
- アップグレード時のクラスタ考慮は不要

---

## 調査結果サマリー

- システムは **SLES for SAP 15 SP4** で稼働中、全モジュールが正常登録済み
- ディスク空き容量は十分 (/ に 7.7G 空き)
- systemd は正常 (Failed: 0)
- リポジトリは susecloud plugin 形式 — SUSE Public Cloud 環境のため、アップグレード用リポジトリは自動切り替えされる
- **SP6 へのマイグレーションパスが利用可能** (`zypper migration --query` で確認済み)
- **HA クラスタは非稼働** — アップグレード時のクラスタ停止手順は不要

---

## 手順（アップグレード実施時の参考）

> **注意**: 以下の手順はアップグレード実施時の参考情報。本 Runbook では調査のみ実施。

```bash
# 1. TTY 付きで VM にログイン
gcloud compute ssh instance-20260315-151733 \
  --zone=asia-northeast1-a \
  --project=tech-trend-1762180118

# 2. マイグレーション可能なターゲットを確認
sudo zypper migration --query

# 3. SP6 を選択してマイグレーション実行（対話形式）
sudo zypper migration
```

---

## 注意事項

1. **`zypper migration --query` は `--ssh-flag="-tt"` が必要**
   - `gcloud compute ssh instance -- sudo zypper migration --query` では TTY 未割り当てで失敗
   - `--ssh-flag="-tt"` を付けることで TTY を強制割り当てし取得成功
   - スクリプトでは `--ssh-flag="-tt"` を使用すること

2. **`SUSEConnect --status` は sudo 必須**
   - `sudo` なしでは `Root privileges are required` エラーが返る

3. **susecloud plugin 形式のリポジトリ**
   - PAYG/BYOS のクラウド環境特有の形式
   - アップグレード後は自動的に SP6 のリポジトリに切り替わる想定だが、移行後の確認が必要

4. **HA Extension (sle-ha) は登録済みだがクラスタ非稼働**
   - `crm status` で `cluster is not available on this node (rc=102)` を確認
   - アップグレード前のクラスタ停止手順は不要
