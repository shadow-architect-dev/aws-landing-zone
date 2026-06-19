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
  - Amazon S3: バケットの削除（`s3:DeleteBucket`）、バージョニングの無効化（`s3:PutBucketVersioning`）
  - Amazon RDS: DB インスタンスおよびクラスタの削除（`rds:DeleteDBInstance`, `rds:DeleteDBCluster`）
  - Amazon DynamoDB: テーブルの削除（`dynamodb:DeleteTable`）

---

## タグポリシー（Tag Policies）によるコストガバナンス

### 1. タグ付与の強制 (`tag-policies/enforce-mandatory-tags.json`)
FinOps（クラウド財務ガバナンス）の観点から、コスト配分（Cost Allocation Tags）やリソース追跡を正確に行うため、以下のリソースに対して特定のタグキーおよび指定値の付与を強制します。

- **対象リソース**: EC2 インスタンス、S3 バケット、RDS インスタンス、RDS クラスタ
- **強制タグルール**:
  - `Environment`: 値として `dev`, `stg`, `prod` のいずれかを強制（表記の統一）。
  - `Project`: プロジェクト名タグのキー存在を強制。

---

## 財務統制・コスト最適化設計 (FinOps / Savings Plans)

AWS Organizations の一括請求（Consolidated Billing）機能の特性を活かし、組織全体のコスト最適化を管理アカウントから主導します。

### 1. 割引共有ポリシー (Savings Plans / RIs Sharing)
*   **管理アカウントでの一括購入**:
    *   **Compute Savings Plans** や **Reserved Instances (RIs)** は、各メンバーアカウント（`dev`, `stg`, `prod`）で個別に購入するのではなく、ボリュームディスカウントが適用される**管理（Management）アカウントで一括購入**します。
*   **割引枠の共有設定 (Sharing)**:
    *   管理アカウントの AWS Billing コンソール（Billing Preferences）にて、**「Discount Sharing（割引共有設定）」**を有効化します（組織作成時にデフォルトで有効）。
    *   これにより、あるアカウント（例: 夜間停止する `dev`）で割引対象のリソースが稼働していない時間帯であっても、余った割引枠が他のアカウント（常時稼働する `stg` や `prod`）に自動的に割り当てられ、組織全体でのコミットメント消化率を最大化し、無駄な支払いを防ぎます。
*   **CDK での扱い**:
    *   AWS の仕様上、長期のコミットメント契約を伴う Savings Plans の購入（契約締結）は CloudFormation/CDK ではサポートされません。そのため、本設計に基づく購入および共有設定は、管理アカウントの Billing コンソールより手動または AWS Billing API を通じて運用管理されます。
