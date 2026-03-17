# ドメインプロファイル: SLES + GCP

対象: SUSE Linux Enterprise Server（SLES）が動作するGCP VMに対する操作。
主なユースケース: SPマイグレーション（例: SP4→SP6）の実行。

---

## 接続設定

```
connection_mode: gcloud-ssh
target: vm_name=<VM名> zone=<ゾーン> project_id=<プロジェクトID>
```

ラッパーコマンド形式:
```
gcloud compute ssh <vm_name> --zone=<zone> --project=<project_id> --ssh-flag="-tt" -- <command>
```

`sudo zypper migration` のような対話的コマンドには必ず `--ssh-flag="-tt"` を付与すること。

---

## 追加許可コマンド

基本許可コマンド（cli-execute/SKILL.md 参照）に加えて以下を許可する。

```
# SLES パッケージ・登録確認（読み取り）
rpm -qa
zypper lr
zypper info
zypper migration --query    # --query フラグ必須（クエリのみ）
SUSEConnect --status

# SLES 実行コマンド（Runbook承認・人間の最終確認後のみ）
sudo zypper migration       # SPマイグレーション実行
sudo SUSEConnect --status   # 登録状態確認（sudo付き）
sudo reboot                 # マイグレーション後の再起動

# GCP 操作
gcloud compute instances describe   # VM情報取得（ブートディスク名など）
gcloud compute disks snapshot       # スナップショット取得
gcloud compute instances stop       # ロールバック時VM停止
gcloud compute instances start      # ロールバック後VM起動
gcloud compute snapshots describe   # スナップショット状態確認
```

---

## 追加禁止コマンド

```
zypper install / update / remove    # パッケージ変更は禁止
zypper migration （--query なし）   # クエリフラグなしの実行は禁止
```

---

## バックアップ手順（スナップショット）

マイグレーション実行前に必ず取得すること。

### 命名規則

```
<vm_name>-pre-migration-<YYYYMMDD>-<HHmm>
例: instance-20260315-134204-pre-migration-20260315-1430
```

### 手順

1. **ブートディスク名取得**
   ```bash
   gcloud compute instances describe <vm_name> \
     --zone=<zone> --project=<project_id> \
     --format="value(disks[0].source.basename())"
   ```

2. **スナップショット取得**
   ```bash
   gcloud compute disks snapshot <disk_name> \
     --zone=<zone> --project=<project_id> \
     --snapshot-names=<snapshot_name>
   ```

3. **取得確認**（`READY` であれば成功）
   ```bash
   gcloud compute snapshots describe <snapshot_name> \
     --project=<project_id> --format="value(status)"
   ```

失敗時: ユーザーに「スナップショットなしで続行するか」を確認する。"yes" の明示的な回答なしには次のステップへ進まない。

---

## ロールバック手順

1. **VM停止**
   ```bash
   gcloud compute instances stop <vm_name> --zone=<zone> --project=<project_id>
   ```

2. **ディスク復元**
   ```bash
   gcloud compute disks create <disk_name>-restored \
     --source-snapshot=<snapshot_name> \
     --zone=<zone> --project=<project_id>
   ```

3. **ディスク差し替え**
   ブートディスクの detach/attach はミスが致命的なため **GCP コンソールでの操作を推奨**。

4. **VM起動**
   ```bash
   gcloud compute instances start <vm_name> --zone=<zone> --project=<project_id>
   ```

---

## ロールバック判断基準

以下のいずれかに該当する場合はロールバックを検討する。

- マイグレーションが途中で中断した
- マイグレーション後にOSが起動しない
- `cat /etc/os-release` でバージョンが期待値と一致しない
- `SUSEConnect --status` で登録状態が異常
- 重要サービスが起動しない
