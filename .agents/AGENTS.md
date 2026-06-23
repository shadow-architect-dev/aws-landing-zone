# AWS Landing Zone プロジェクトカスタムルール

本リポジトリ (`aws-landing-zone`) のインフラ管理および運用において適用すべき共通の設計原則、状態管理ルール、およびアカウントガバナンスの制約です。

## 1. 状態管理およびロックのルール (State Management & Locking)

- **S3によるセキュアな状態管理**:
  - Terraform のステートファイル（`tfstate`）は、管理アカウントに配置された AWS S3 バケットでセキュアに管理すること。
  - ステート保存用バケットは、必ず **バージョニング** および **SSE-KMS 暗号化** を有効化すること。
- **DynamoDBによるステートロックの必須化**:
  - 複数人、複数環境、または CI/CD パイプラインでのデプロイ競合による状態ファイルの破損を防ぐため、DynamoDB テーブルを使用した **ステートロック (State Locking)** を必須の構成とすること。

## 2. マルチアカウント払い出しの制約 (Multi-Account Provisioning & Governance)

- **Control Tower Account Factory との連携**:
  - 各環境（Dev/Stg/Prod）などの AWS アカウントの新規作成・払い出しは、生の Organizations API (`aws_organizations_account` リソース等の直接操作) を避け、必ず **AWS Control Tower / AWS Landing Zone (AFT や LZA 等)** の Account Factory (Service Catalog 製品) 経由で安全に払い出し、組織の初期セキュリティベースライン（ログ集約、地域制限SCP等）を適用すること。
- **物理的な隔離設計の遵守**:
  - アカウント間は、物理的にネットワーク（VPC）および IAM 権限境界が完全に隔離・独立されるように設計し、クロスアカウントのアクセスは定義された OIDC デプロイロールや共通ログ集約ロールなどの明示的な許可ポリシーを介した通信のみに制限すること。
