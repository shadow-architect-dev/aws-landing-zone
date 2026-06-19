# ガードレール（SCP: サービスコントロールポリシー）設計

AWS Organizations の SCP（Service Control Policy）を使用して、組織全体のガードレールを設定します。
SCP は IAM ポリシーと類似していますが、組織内のメンバーアカウントにおける最大権限を制限するために使用され、管理アカウントの Root ユーザーや各アカウントの Administrator 権限であっても制限をオーバーライドすることはできません。

## 適用ポリシー一覧

### 1. 許可リージョン制限 (`scp/restrict-regions.json`)
日本国内のワークロード実行を前提とし、東京リージョン（`ap-northeast-1`）以外のリージョンでの不要なリソース作成を禁止します。
これにより、意図しない他リージョンでのリソース作成や、他リージョンを踏み台にしたセキュリティ侵害を防御します。

- **対象外となるグローバルサービス (例外)**:
  - IAM, Route 53, CloudFront, Support, Organizations, WAF など、グローバルに配置されるサービスおよび API アクションは制限から除外されます。

### 2. セキュリティ監視機能の無効化・削除防止 (`scp/protect-security-services.json`)
セキュリティ・ガバナンスのベースラインとなる各種セキュリティ監視サービスの無効化、ログ設定の削除などを制限します。
各アカウント内の管理者であっても、監査ログの停止や監視ツールの無効化を行うことはできません。

- **保護対象サービス**:
  - AWS CloudTrail: 証跡の削除、更新、記録停止の禁止
  - Amazon GuardDuty: ディテクターの削除、一時停止の禁止
  - AWS Security Hub: 有効化設定の無効化・削除の禁止
  - AWS Config: レコーダーおよびデリバリーチャンネルの停止・削除の禁止

### 3. 本番データの削除防止 (`scp/prevent-prod-deletion.json`)
誤操作や不正アクセスによるデータ消失を防ぐため、本番環境アカウント（または本番OU）での特定の破壊的操作を禁止します。

- **保護対象リソースおよび操作**:
  - Amazon S3: バケットの削除（`s3:DeleteBucket`）
  - Amazon RDS: DB インスタンスおよびクラスタの削除（`rds:DeleteDBInstance`, `rds:DeleteDBCluster`）
  - Amazon DynamoDB: テーブルの削除（`dynamodb:DeleteTable`）
