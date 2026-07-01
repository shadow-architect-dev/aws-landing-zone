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

## 3. AI エージェント（Antigravity）に対する権限制約 (Read-Only Policy)

- **ターゲット外リポジトリへの書き込み禁止 (Strict Read-Only for External Repositories)**:
  - Antigravity は、`aws-landing-zone*` (本リポジトリおよび `aws-landing-zone-aft-*` などの派生リポジトリ) **以外**のいかなるリポジトリ配下のファイルに対しても、新規作成・上書き・編集・削除を一切行ってはならず、完全な読み取り専用（Read-Only）として振る舞うこと。
  - 本リポジトリ（`aws-landing-zone`）自体や関連 AFT リポジトリ群に対しては、インフラコード（HCL）の作成やドキュメント（README/ランブック等）の修正のための書き込みを許可する。
- **デプロイおよび破壊的コマンド実行の禁止**:
  - 本番/検証環境へのインフラデプロイ（`terraform apply`）やテスト実行、その他重大なコマンド実行は、AI環境からは一切実行してはならず、すべてユーザーのローカル環境での手動操作に委ねること。
  - 設計の確認やコードリサーチのためのファイル閲覧（`view_file`）のみを許可する。
