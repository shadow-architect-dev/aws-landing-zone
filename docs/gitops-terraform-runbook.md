# AWS Landing Zone CDK から Terraform (HCL) への移行および GitOps アカウント管理ランブック

本ドキュメントは、既存の TypeScript/AWS CDK で管理されている AWS Landing Zone 環境を、本番リソースを一切破壊せずにプレーンな **Terraform (HCL)** へ安全に移行するための手順および、移行完了後の **`accounts.yaml` を用いた GitOps アカウント管理** の運用ガイドです。

---

## 1. CDK から Terraform への移行手順 (全 6 ステップ)

移行作業中も本番環境のサービスは無停止であり、既存の AWS 組織（OU、アカウント）、S3 ログバケット、KMS 暗号化キーなどの実リソースはすべて維持されます。

### Step 1: Terraform バックエンドおよび OIDC の初期ブートストラップ

本 Landing Zone では、状態管理を強固にするため、専用の `bootstrap` コードを使用して S3 バケットおよび DynamoDB テーブルを先にプロビジョニングします。

1. **ブートストラップ用インフラのプロビジョニング (ローカル実行)**:
   - ターミナルで `terraform/bootstrap` ディレクトリに移動します：
     ```bash
     cd terraform/bootstrap
     ```
   - 初期化と適用を実行し、ステートバケットと DynamoDB テーブルを作成します（初回のみローカルのステートとして作成されます）：
     ```bash
     terraform init
     terraform apply
     ```
   - *注意*: 作成される S3 バケット（`landingzone-terraform-state-<管理アカウントID>`）には `prevent_destroy = true` が設定されており、誤って削除されることが防止されています。
2. **メイン基盤側バックエンドの初期化とステート移行**:
   - ルートの `terraform/` ディレクトリに戻ります：
     ```bash
     cd ..
     ```
   - ルートディレクトリで初期化を実行します。これにより、[backend.tf](file:///c:/Git/aws-landing-zone/terraform/backend.tf) の設定に基づき、ローカルのステートファイルを新しく作成したリモート S3 バケットへ自動アップロード（マイグレーション）するか確認されます：
     ```bash
     terraform init
     ```
   - 画面の確認プロンプトに対して `yes` と答えることで、リモートバックエンドへの移行が完了します。
3. **OIDC ロールの確認**:
   - GitHub Actions 等の CI/CD ツールから OIDC 経由でデプロイするため、CDK 側で作成した `GitHubActionsWorkflowDeployRole` を確認します。移行後は Terraform がこのロールの管理を引き継ぎます。

### Step 2: 構成パラメータの設定
1. [terraform/variables.tf](file:///c:/Git/aws-landing-zone/terraform/variables.tf) を開き、現在稼働している各 AWS アカウントの12桁の ID、OU ID、KMSキーID、SSO インスタンス ARN などを実際の値に設定します。

### Step 3: Terraform 初期化
1. ターミナルで `terraform` ディレクトリに移動し、初期化を行います：
   ```bash
   cd terraform
   terraform init
   ```

### Step 4: 既存リソースのインポート (重要)
AWS リソースを再作成（破壊）せずに状態管理（State）へ取り込むため、Terraform 1.5 で導入された **`import` ブロック**（[imports.tf](file:///c:/Git/aws-landing-zone/terraform/imports.tf)）を使用します。

1. [imports.tf](file:///c:/Git/aws-landing-zone/terraform/imports.tf) に、既存の AWS 組織、OU、S3バケット、KMSキー、SSO許可セットなどの実際の ID/ARN を転記します。
2. 以下のプランコマンドを実行し、インポート内容を確認します：
   ```bash
   terraform plan
   ```
   - *期待される出力*: プラン結果に `Objects to import:` として対象のリソースが一覧表示されていることを確認します。
3. 以下のコマンドを実行してインポートを確定させます（AWS リソース自体は変更されず、State ファイルへの書き込みのみが発生します）：
   ```bash
   terraform apply
   ```

### Step 5: 差分確認 (No Changes の確認)
1. インポート完了後、再度プランを実行します：
   ```bash
   terraform plan
   ```
2. **「No changes. Your infrastructure matches the configuration. (差分なし)」** が出力されることを確認します。
   - *差分（Destroy / Create / Update）がある場合*: 既存の AWS 設定と Terraform コードのパラメータ（KMSポリシー、S3ポリシー、SSO設定など）の間に不一致があります。差分が「0」になるまで Terraform コードを微調整してください。**差分が完全になくなるまで絶対に次のステップに進まないでください。**

### Step 6: 旧 CDK スタックの安全な削除 (クリーンアップ)
Terraform への管理移譲が完全に完了したことを確認したら、古い CDK スタックをクリーンアップします。

1. **CDK 削除ポリシーの再確認**:
   - [lib/stacks/log-archive-stack.ts](file:///c:/Git/aws-landing-zone/lib/stacks/log-archive-stack.ts) などの CDK ソースコードで、S3 バケット（`LogArchiveBucket`）や KMS キー（`CloudTrailEncryptionKey`）の `removalPolicy` が **`cdk.RemovalPolicy.RETAIN`** に設定されていることを二重チェックします。これにより、CDK 削除時にログデータや暗号化キーが消滅するのを防ぎます。
2. **CDK スタックの削除実行**:
   - 管理アカウントのコンソール（AWS CloudFormation）から、または以下のコマンドで CDK スタックを安全に削除します：
     ```bash
     npx cdk destroy --all
     ```
   - CloudFormation スタックが削除されても、リソース自体は `RETAIN` 設定により AWS 上に残ります。以後は Terraform のみが唯一の IaC 管理ツールとなります。

---

## 2. アカウント払い出し運用ガイド (GitOps / Control Tower 連携)

移行完了後、新しい AWS アカウントの追加は、[accounts.yaml](file:///c:/Git/aws-landing-zone/terraform/accounts.yaml) を用いて GitOps で管理します。

```
                    ┌──────────────────────────────┐
                    │  accounts.yaml にアカウント追加  │
                    └──────────────┬───────────────┘
                                   │ (PR マージ)
                                   ▼
                    ┌──────────────────────────────┐
                    │      terraform apply         │
                    └──────────────┬───────────────┘
                                   │ (Service Catalog Product 起動)
                                   ▼
                    ┌──────────────────────────────┐
                    │ AWS Control Tower            │
                    │   - アカウントの新規作成       │
                    │   - ガードレール・ログ集約の適用 │
                    └──────────────────────────────┘
```

### 1. アカウントの新規追加手順

1. **アカウント定義の追加**:
   - [terraform/accounts.yaml](file:///c:/Git/aws-landing-zone/terraform/accounts.yaml) を開き、新規追加したいアカウントの定義を末尾に追記します。
     ```yaml
     - account_name: "Eks-Workload-Prod"
       account_email: "aws-root+eks-prod@example.com"
       organizational_unit: "Workloads"
     ```
2. **プルリクエストの作成とマージ**:
   - 変更を Git ブランチにコミットして PR を作成します。
   - レビュー承認後、`main` ブランチにマージします。
3. **自動プロビジョニングの開始**:
   - CI/CD パイプラインが `terraform apply` を実行します。
   - `aws_servicecatalog_provisioned_product.control_tower_account["Eks-Workload-Prod"]` リソースが作成され、AWS Control Tower Account Factory にアカウント作成が要求されます。
   - **所要時間**: 約15〜30分。完了すると、ルートメールアドレス宛てに AWS からウェルカムメールが届きます。
4. **事後設定**:
   - 作成された新しいアカウントのアカウント ID (12桁) を取得します。
   - 必要に応じて、`variables.tf` へのアカウント ID 追加、および `IdentityStack` などのアカウント特定ポリシーを適用するために再デプロイを行います。

### 2. アカウント削除（クローズ）手順

> [!WARNING]
> **注意: Terraform の挙動制限**
> `accounts.yaml` からアカウント定義を削除して `terraform apply` を実行すると、Service Catalog 上のプロビジョニング関連付け（Provisioned Product）は登録解除（削除）されますが、**AWS アカウント自体が自動クローズされるわけではありません。**

不要になったアカウントをクローズする際は、以下のハイブリッド手順を実施します：

1. **コードのクリーンアップ**:
   - `accounts.yaml` から対象アカウントの定義を削除し、Git にマージして `terraform apply` を完了させます。
2. **手動によるアカウント閉鎖**:
   - AWS 管理アカウントにログインし、**AWS Organizations コンソール** に移動します。
   - クローズ対象のアカウントを選択し、**「閉じる (Close account)」** をクリックして解約手続きを実行します。

---

## 3. EKS 3層 Web アプリプロジェクト向けのアカウント払い出しと初期設定手順

新たに構築する EKS プロジェクトリポジトリ (`YOUR_ORGANIZATION/aws-eks-three-tier`) のために払い出した 3 つのアカウント (`eks-three-tier-dev`, `eks-three-tier-stg`, `eks-three-tier-prod`) の運用手順です。

### 3-1. アカウントの払い出しと OU 配置
1. [accounts.yaml](file:///c:/Git/aws-landing-zone/terraform/accounts.yaml) に追加した 3 つのアカウント定義をマージして `terraform apply` します。
2. これにより、以下の nested OU（入れ子構造）が自動的に作成され、各アカウントが配置されます：
   - `Workloads/Development` ➔ `eks-three-tier-dev`
   - `Workloads/Staging` ➔ `eks-three-tier-stg`
   - `Workloads/Production` ➔ `eks-three-tier-prod`

### 3-2. OIDC 連携デプロイロールの適用
1. 各アカウントのプロビジョニング完了後、実際のアカウント ID を `variables.tf` の `accounts` マップに追加して再デプロイします。
2. デプロイにより、3 つのアカウントそれぞれの内部に以下のリソースが自動適用されます：
   - **OIDC アイデンティティプロバイダー** (GitHub Actions との信頼関係用)
   - **`GitHubActionsEKSDeployRole` ロール** (権限: `AdministratorAccess`、セッション有効時間: 2時間)
3. これにより、GitHubリポジトリ `YOUR_ORGANIZATION/aws-eks-three-tier` の Actions ワークフローは、アクセスキーを発行することなく各 AWS 環境へデプロイ可能になります。

### 3-3. IAM Identity Center (SSO) アクセス権限マッピング
Google Workspace と同期された既存の Google グループに対し、以下のアクセス制御が自動で紐付けられます：
- **`aws-dev-group` (開発者グループ)**:
  - `eks-three-tier-dev` ➔ `power_user` (DeveloperPermissionSet に相当する開発者権限)
  - `eks-three-tier-stg` ➔ `read_only` (検証環境に対する参照専用権限)
  - `eks-three-tier-prod` ➔ `read_only` (本番環境に対する平常時参照専用権限 / FISC準拠)
- **`aws-ops-group` (緊急対応/SREグループ)**:
  - `eks-three-tier-prod` ➔ `admin` (BreakGlassPermissionSet に相当する一時特権管理者権限、平常時のグループメンバーは「空」)

### 3-4. ワークロード側リポジトリへのパラメータ連携 (`shared-outputs.md`)
デプロイ完了後、`terraform output` により出力される以下のパラメータを、新規リポジトリ `aws-eks-three-tier` 側の `/docs/governance/shared-outputs.md` 等に書き込みます。

* **EKS 開発環境 (Dev)**:
  - AWS Account ID: `888888888888` (※実値へ置き換え)
  - OIDC Deploy Role ARN: `arn:aws:iam::888888888888:role/GitHubActionsEKSDeployRole`
* **EKS 検証環境 (Stg)**:
  - AWS Account ID: `999999999999`
  - OIDC Deploy Role ARN: `arn:aws:iam::999999999999:role/GitHubActionsEKSDeployRole`
* **EKS 本番環境 (Prod)**:
  - AWS Account ID: `101010101010`
  - OIDC Deploy Role ARN: `arn:aws:iam::101010101010:role/GitHubActionsEKSDeployRole`
