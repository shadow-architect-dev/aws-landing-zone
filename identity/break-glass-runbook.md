# 緊急アクセス（Break-Glass）運用・監査ランブック

本ランブックは、本番環境（`prod`）でシステム障害等が発生し、通常の CI/CD パイプライン（GitHub Actions）が利用できない、または緊急のデバッグ・復旧作業が必要となった場合に、一時的に特権管理者権限（AdministratorAccess）を取得して緊急対応を行い、事後に厳格な監査を実施するための手順書です。

---

## 1. 緊急アクセスのライフサイクルと役割

平常時、本番環境の特権管理者権限を持つ Google グループ `aws-breakglass-group` のメンバーは **「空（メンバーなし）」** とし、いかなる人間も本番特権アクセスを持たない状態（No Human Access）で運用します。

```
[ 平常時: グループ空 ]
     │
     ▼
[ 1. 緊急申請・承認 ] ──── 障害検知、承認者の承認
     │
     ▼
[ 2. 権限付与 (IdP) ] ──── Google Workspace グループへ対象ユーザーを追加 (SCIMで即時同期)
     │
     ▼
[ 3. 緊急作業実施 ]   ──── AWS SSO から本番 AdministratorAccessSet でログインし作業実施
     │
     ▼
[ 4. 権限剥奪 (IdP) ] ──── Google Workspace グループから対象ユーザーを削除 (SCIMで同期)
     │
     ▼
[ 5. 事後ログ監査 ]   ──── CloudTrail を用いて作業時間帯の操作ログを全件突合・承認
```

---

## 2. 緊急アクセスの申請と有効化手順

### ステップ 2-1: 緊急アクセスの申請と承認
1. **申請者 (作業者)**: 以下の情報をチケットシステムまたは緊急用コミュニケーションチャネルで起票し、承認を求めます。
   - **対象 AWS アカウント**: `prod`
   - **申請理由・障害内容**: (例: CI/CDランナー障害に伴う、EKSクラスタの緊急スケール変更)
   - **作業予定時間**: (例: 2026/06/22 17:00 〜 19:00 の最大2時間)
   - **作業予定メンバーのメールアドレス**: `developer@example.com`
2. **承認者 (セキュリティ管理者または部門長)**:
   - 申請内容の妥当性と時間枠を精査し、承認を明示します。

### ステップ 2-2: Google Workspace でのメンバー追加
1. **承認者または Google Workspace 特権管理者**: Google 管理コンソール (admin.google.com) にログインします。
2. **「ディレクトリ」 > 「グループ」** に移動します。
3. **`aws-breakglass-group`** を選択します。
4. **「メンバーを追加」** をクリックし、承認された作業者（例: `developer@example.com`）のメールアドレスを入力して追加します。
5. Google Workspace SCIM プロビジョニングにより、数分以内に AWS IAM Identity Center 側へグループメンバー情報が同期されます。
   - *即時反映したい場合*: Google 管理コンソールの自動プロビジョニング設定から「同期を強制実行」するか、AWS SSO 側で同期ステータスを確認します。

---

## 3. 緊急作業の実施

1. **作業者**: `aws-breakglass-group` に追加された後、AWS アクセスポータル (AWS SSO ログイン画面) にアクセスします。
2. Google Workspace アカウントで認証後、アクセスポータル上に **`prod` アカウント** とそれに紐づく **`AdministratorAccessSet`** のロールが表示されていることを確認します。
3. `AdministratorAccessSet` の「Management console」リンクをクリックしてログインします。
4. **作業制限**: 
   - 事前に承認された緊急復旧手順に沿った最小限の操作のみを行います。
   - 作業中の操作履歴やターミナルログ、意図した変更内容をすべて記録します。

---

## 4. 権限剥奪の手順（作業完了後）

緊急作業が完了、または承認された制限時間に達した場合は、直ちに権限を剥奪して平常状態に戻します。

1. **作業者**: 作業完了を承認者へ報告します。
2. **Google Workspace 管理者**: Google 管理コンソールの **`aws-breakglass-group`** の管理画面を開きます。
3. 対象の作業者（例: `developer@example.com`）を選択し、**「グループから削除」** をクリックします。
4. SCIM プロビジョニングにより、AWS IAM Identity Center 側のグループメンバーから対象ユーザーが削除され、本番環境への管理者アクセス権が即座に剥奪されます。

---

## 5. 事後監査（CloudTrail ログ監査）手順

金融・FISC 基準に準拠するため、緊急作業期間中のすべての操作を監査し、不正アクセスや不要な変更が行われていないことを検証します。

### ステップ 5-1: 監査用パラメータの整理
- **作業者**: `developer@example.com`
- **緊急ロール名**: `AWSReservedSSO_AdministratorAccessSet_xxxxxxxxx`
- **作業開始時刻 (UTC/JST)**: `2026-06-22T08:00:00Z` (17:00 JST)
- **作業終了時刻 (UTC/JST)**: `2026-06-22T10:00:00Z` (19:00 JST)

### ステップ 5-2: Athena または CloudTrail Lake によるログ検索
監査アカウント（`Audit`）または管理アカウントの CloudTrail ログ保管用 S3 バケットに対し、以下のクエリ（または CloudTrail コンソールの「イベント履歴」フィルタリング）を実行します。

#### **検索条件の例（Amazon Athena クエリ）**
```sql
SELECT 
    eventtime,
    eventname,
    eventsource,
    awsregion,
    sourceipaddress,
    useridentity.principalid,
    useridentity.sessioncontext.sessionissuer.arn as role_arn,
    requestparameters
FROM 
    "secure_log_database"."cloudtrail_logs"
WHERE 
    -- 1. 本番アカウントを指定
    accountid = '777777777777'
    -- 2. 緊急作業時間帯を指定 (UTC)
    AND eventtime >= '2026-06-22T08:00:00Z'
    AND eventtime <= '2026-06-22T10:00:00Z'
    -- 3. SSOのBreak-Glassロールと作業者メールアドレスで絞り込み
    AND useridentity.principalid LIKE '%developer@example.com%'
    AND useridentity.sessioncontext.sessionissuer.arn LIKE '%AdministratorAccessSet%'
ORDER BY 
    eventtime ASC;
```

#### **手動確認する場合（CloudTrail イベント履歴のフィルタ）**
1. 本番環境（`prod`）の AWS コンソールにログインし、**CloudTrail > イベント履歴** に移動します。
2. 以下のフィルタを適用します：
   - **ユーザー名**: `developer@example.com` （※SSOの場合、ユーザー名または PrincipalID にメールアドレスが含まれます）
   - **時間範囲**: 作業開始時刻から作業終了時刻までを指定。
3. 読み込み専用ではない書き込み操作（例: `Put*`, `Create*`, `Delete*`, `Update*`, `Authorize*`, `Attach*` などの API）を抽出します。

### ステップ 5-3: 監査チェックリスト
監査者は以下の項目を確認し、監査レポートを作成して署名（または承認）します。

* [ ] **チェック 1**: CloudTrail 上で検出された操作が、緊急作業申請チケットに記載された「作業内容（例: EKSスケール変更）」と完全に一致しているか。
* [ ] **チェック 2**: 申請されていないリソースの変更や、IAMユーザー/ロールの作成、SCPの変更、ログ設定の変更（証跡の停止など）が行われていないか。
* [ ] **チェック 3**: 作業期間が終了した時刻以降に、当該ユーザーによる本番管理者操作ログが記録されていないこと。
* [ ] **チェック 4**: Google Workspace 上の `aws-breakglass-group` のメンバーが、現在「空」になっていること。

監査結果は、インシデント管理チケットに添付され、セキュリティ委員会や社内監査チームへの報告資料として 7 年間保存されます。
