# Runbook: SLES SP6→SP7 アップグレード前環境調査
作成日: 2026-03-30

## 調査環境
- ホスト名: instance-20260330-094238
- OS: SUSE Linux Enterprise Server for SAP Applications 15 SP6 (VARIANT_ID=sles-sap)
- カーネル: 6.4.0-150600.23.84-default
- アーキテクチャ: x86_64
- 接続方式: gcloud-ssh
- 接続先: vm_name=instance-20260330-094238 / zone=asia-northeast1-b / project_id=tech-trend-1762180118

## Confirmed Facts

- **OS登録状態**: SLES_SAP 15.6、sle-ha 15.6 および以下のモジュールが Registered
  - sle-module-basesystem, sle-module-desktop-applications, sle-module-development-tools
  - sle-module-python3, sle-module-sap-applications, sle-module-server-applications
  - sle-module-systems-management
- **未登録モジュール（5件）**:
  - sle-module-confidential-computing
  - sle-module-containers
  - sle-module-live-patching
  - sle-module-public-cloud
  - sle-module-web-scripting
- **ディスク**: sda (10GB)、`/` に 2.7GB/10G 使用（28%）— 空き十分
- **ブートディスク**: sda（GCPスナップショット取得対象）
- **失敗サービス**: 0件
- **SCC接続**: HTTP 200（正常）
- **ネットワーク**: eth0 UP / 10.146.0.9
- **未適用パッチ**: 60件以上（kernel-default, systemd, glibc, curl 等）
- **`zypper migration --query` の結果**: エラー終了（exit status 1）

  ```
  Can't get available migrations from server: Error: Registration server returned
  'The requested products 'Confidential Computing Module 15 SP6 x86_64,
  Containers Module 15 SP6 x86_64, SUSE Linux Enterprise Live Patching 15 SP6 x86_64,
  Public Cloud Module 15 SP6 x86_64, Web and Scripting Module 15 SP6 x86_64'
  are not activated on the system.' (422)
  ```

## Assumptions

- 422エラーは 2026-03-17 の同環境調査と同一パターン。未登録モジュールの対処後に解消される見込み。

## Missing Evidence

- 未登録モジュール対処後に SP7 マイグレーションパスが登録サーバーから提示されるかどうか未確認。

## 調査結果サマリー

SLES 15 SP6 (SLES_SAP) の環境。ディスク・ネットワーク・サービスは正常稼働中。SUSE 登録も主要モジュールは完了している。

**SP7 アップグレード前の重要ブロッカーあり:**

`zypper migration --query` が以下のエラーで失敗している:

```
The requested products 'Confidential Computing Module 15 SP6 x86_64,
Containers Module 15 SP6 x86_64, SUSE Linux Enterprise Live Patching 15 SP6 x86_64,
Public Cloud Module 15 SP6 x86_64, Web and Scripting Module 15 SP6 x86_64'
are not activated on the system.' (422)
```

システムに **SUSEConnect で未登録のモジュール 5 件** が存在するため、マイグレーションツールが利用可能な移行パスを取得できていない。
SP7 移行前にこのブロッカーを解消する必要がある。

また、SP6 適用可能なアップデートが 60 件以上残っており、SP7 移行前に SP6 を最新化することを推奨する。

---

## 手順

| ステップ | 実行方法 |
|---------|---------|
| スナップショット取得〜ステップ 3 | **cli-execute で自動実行可** |
| ステップ 4（zypper migration） | **手動実行**（対話操作あり） |

### 前提条件
- GCP スナップショット（バックアップ）取得済みであること（「バックアップ・ロールバック手順」を参照）
- 未登録モジュール 5 件の対処方針を事前に決定していること（選択肢 A/B を参照）

### ステップ 1: SP6 アップデートを適用する（cli-execute）

```bash
sudo zypper patch
```

> 60 件以上のアップデートが存在する（kernel, glibc, systemd, curl 等）。
> カーネルアップデートが含まれる場合は再起動が必要。

```bash
sudo reboot
```

### ステップ 2: 未登録モジュールの対処（cli-execute / いずれかを選択）

#### 選択肢 A: 未登録モジュールを SUSEConnect で登録する（推奨）

不要でなければ登録して migration に含める:

```bash
sudo SUSEConnect -p sle-module-public-cloud/15.6/x86_64
sudo SUSEConnect -p sle-module-containers/15.6/x86_64
sudo SUSEConnect -p sle-module-web-scripting/15.6/x86_64
sudo SUSEConnect -p sle-module-live-patching/15.6/x86_64
sudo SUSEConnect -p sle-module-confidential-computing/15.6/x86_64
```

#### 選択肢 B: 不要なモジュールを登録解除する

システムで不要なモジュールと判断した場合:

```bash
sudo SUSEConnect -d -p sle-module-confidential-computing/15.6/x86_64
sudo SUSEConnect -d -p sle-module-containers/15.6/x86_64
sudo SUSEConnect -d -p sle-module-live-patching/15.6/x86_64
sudo SUSEConnect -d -p sle-module-public-cloud/15.6/x86_64
sudo SUSEConnect -d -p sle-module-web-scripting/15.6/x86_64
```

> どちらの選択肢を選ぶかは、本番環境の用途に応じて事前に確認すること。

### ステップ 3: マイグレーションターゲットの確認（cli-execute）

未登録モジュールの対処後に再実行:

```bash
sudo zypper migration --query
```

SP7 のターゲットが表示されることを確認してから次のステップへ進む。

### ステップ 4: SP7 マイグレーション実行（**手動実行**）

ターゲット確認後、ターミナルから直接実行すること:

```bash
gcloud compute ssh instance-20260330-094238 \
  --zone=asia-northeast1-b --project=tech-trend-1762180118 \
  --ssh-flag="-tt" -- sudo zypper migration
```

> 対話的な選択（ライセンス同意・ターゲット選択等）が発生するため、手動実行すること。

---

## バックアップ・ロールバック手順

> GCP スナップショットを事前取得すること。

### バックアップ情報

| 項目 | 値 |
|------|----|
| バックアップ名 | （cli-execute 実行後に記入） |
| 対象リソース | instance-20260330-094238 / ディスク sda |
| 取得ステータス | 未実施 |
| 取得日時 | — |

### ロールバック手順

1. GCP コンソール または gcloud CLI でスナップショットからディスクを復元
2. VM を停止し、ブートディスクをスナップショットから作成したディスクに差し替えて起動

---

## 注意事項

- `zypper migration --query` は422エラーで終了。SP7マイグレーション可否は未確認（ブロッカー解消後に再確認必要）
- `sudo zypper migration` は対話的操作が必要なため cli-execute からの自動実行は不可。手動実行すること
- SP6 未適用パッチ 60件以上あり。マイグレーション前に `zypper patch` で最新化を推奨
- ディスク空き容量は十分（72%空き）だが、マイグレーション後のカーネル・パッケージ増加を考慮すること
