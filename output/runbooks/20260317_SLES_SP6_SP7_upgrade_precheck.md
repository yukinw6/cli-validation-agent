# Runbook: SLES SP6からSP7へのアップグレード前環境調査
作成日: 2026-03-17

## 調査環境
- ホスト名: instance-20260317-154124
- OS: SUSE Linux Enterprise Server 15 SP6 (SLES_SAP)
- カーネル: 6.4.0-150600.23.84-default
- アーキテクチャ: x86_64
- 接続方式: gcloud-ssh
- 接続先: vm_name=instance-20260317-154124 / zone=asia-northeast1-b / project_id=tech-trend-1762180118

---

## Confirmed Facts

| 項目 | 値 |
|------|----|
| OS | SUSE Linux Enterprise Server for SAP Applications 15 SP6 |
| カーネル | 6.4.0-150600.23.84-default |
| アーキテクチャ | x86_64 |
| ルートディスク | /dev/sda（10G）、使用率 27%（2.7G/10G） |
| /boot/efi | /dev/sda2（20M）、使用率 19% |
| ブートディスク名 | sda |
| ネットワーク | eth0 / 10.146.0.8/32 |
| 稼働サービス数 | 22件（Google Compute Engine Agent 含む） |
| 利用可能アップデート | 53件 |

### SUSE 登録済みモジュール（Registered）

| モジュール | バージョン |
|-----------|-----------|
| SLES_SAP | 15.6 |
| sle-ha | 15.6 |
| sle-module-basesystem | 15.6 |
| sle-module-desktop-applications | 15.6 |
| sle-module-development-tools | 15.6 |
| sle-module-python3 | 15.6 |
| sle-module-sap-applications | 15.6 |
| sle-module-server-applications | 15.6 |
| sle-module-systems-management | 15.6 |

### インストール済みだが未登録（Not Registered）のモジュール

| モジュール |
|-----------|
| sle-module-confidential-computing |
| sle-module-containers |
| sle-module-live-patching |
| sle-module-public-cloud |
| sle-module-web-scripting |

---

## Assumptions

- 未登録モジュールのリポジトリが無効化されているため、これらのパッケージは現状アップデートを受けていないと想定
- GCP 環境のため、Google Cloud Ops Agent は Google 側リポジトリで独自管理

---

## Missing Evidence

- **`zypper migration --query` が失敗（エラー 422）**: 未登録の5モジュールが原因。SP7 マイグレーションターゲットの自動照会が取得できていない
- SP7 への正常なマイグレーションパスの確認ができていない（事前に上記ブロッカーを解消する必要あり）

---

## 調査結果サマリー

SLES 15 SP6 (SLES_SAP) の環境。ディスク・ネットワーク・サービスは正常稼働中。SUSE 登録も主要モジュールは完了している。

**SP7 アップグレード前の重要ブロッカーあり:**

`zypper migration --query` が以下のエラーで失敗している:

```
Can't get available migrations from server: Error: Registration server returned
'The requested products 'Confidential Computing Module 15 SP6 x86_64,
Containers Module 15 SP6 x86_64, SUSE Linux Enterprise Live Patching 15 SP6 x86_64,
Public Cloud Module 15 SP6 x86_64, Web and Scripting Module 15 SP6 x86_64'
are not activated on the system.' (422)
```

これはシステムに**インストール済みだが SUSEConnect に未登録のモジュール**が5件存在するため。
マイグレーション実行前にこれを解消する必要がある。

また、SP6 適用可能なアップデートが 53 件残っており、SP7 移行前に SP6 を最新化することを推奨する。

---

## 手順

### 前提条件
- GCPスナップショット（バックアップ）取得済みであること（手順は「バックアップ・ロールバック手順」を参照）
- SP6 パッチが最新化済みであること

### ステップ 1: SP6 アップデートを適用する

```bash
sudo zypper patch
```

> 53 件のアップデートが存在する（kernel, glibc, systemd, curl 等）。
> パッチ適用後、カーネルアップデートがある場合は再起動が必要。

```bash
sudo reboot
```

### ステップ 2: 未登録モジュールの対処（いずれかを選択）

#### 選択肢 A: 未登録モジュールを SUSEConnect で登録する（推奨）

不要でなければ登録して migration に含める:

```bash
# 例: Public Cloud Module を登録
sudo SUSEConnect -p sle-module-public-cloud/15.6/x86_64
```

未登録の各モジュールについて同様に実行。

#### 選択肢 B: 未登録モジュールを削除・無効化する

マイグレーション対象から外す場合:

```bash
# 例: migration 実行時に除外指定（zypper migration の --product オプションを活用）
sudo zypper migration --query --allow-vendor-change
```

> SUSEサポートに確認の上、適切なオプションを選択すること。

### ステップ 3: マイグレーションターゲットの再確認

未登録モジュールの対処後に再実行:

```bash
sudo zypper migration --query
```

SP7 のターゲットが表示されることを確認する。

### ステップ 4: SP7 マイグレーション実行

ターゲット確認後:

```bash
sudo zypper migration
```

---

## バックアップ・ロールバック手順

### バックアップ情報

| 項目 | 値 |
|------|----|
| バックアップ名 | `instance-20260317-154124-pre-migration-20260317-2255` |
| 対象リソース | instance-20260317-154124 / ディスク: instance-20260317-154124 |
| 取得ステータス | **READY** |
| 取得日時 | 2026-03-17 22:55 |

### GCP スナップショット取得（参考）

```bash
gcloud compute disks snapshot <DISK_NAME> \
  --zone=asia-northeast1-b \
  --project=tech-trend-1762180118 \
  --snapshot-names=<SNAPSHOT_NAME>
```

ブートディスク名は `sda`（GCPインスタンス名から特定すること）。

### ロールバック手順（GCPスナップショットから復元）

1. インスタンスを停止
2. ブートディスクをスナップショットから復元、または新規ディスクを作成してアタッチ
3. インスタンスを起動して動作確認

---

## 注意事項

1. **`zypper migration --query` エラー（422）**: 未登録モジュール5件が原因。マイグレーション実行前に必ず解消すること。
2. **SP6 アップデート 53 件未適用**: kernel・glibc・systemd を含む。SP7 移行前にパッチ適用と再起動を推奨。
3. **ディスク容量**: ルートパーティション（/dev/sda3）は 10G 中 2.7G 使用（27%）。SP7 移行パッケージのダウンロード・展開に問題はない見込み。
4. **GCP環境固有**: Google Cloud Ops Agent リポジトリ（google-cloud-ops-agent）はSP移行後に再設定が必要な場合がある。
5. **SLES_SAP variant**: sle-ha（High Availability Extension）も登録済み。HA クラスタ構成がある場合は別途クラスタの移行手順を確認すること。
