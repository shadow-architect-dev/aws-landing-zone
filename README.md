# aws-landing-zone (AWS Multi-Account Governance Repository)

このリポジトリは、AWS Organizations および AWS Control Tower を用いて、エンタープライズ規模のマルチアカウント構造、ガードレール（SCP）、およびガバナンスをコードで管理するためのインフラベースラインテンプレートです。

個別ワークロードリポジトリである **[learning-ts-concepts](https://github.com/shadow-architect-dev/learning-ts-concepts)** と連携し、安全な3層Webアーキテクチャを実行するための「土台（プラットフォーム）」を構成します。

---

## 🏗️ 組織・アカウント設計（Landing Zone）

本リポジトリでは、以下の Organizations OU（組織単位）およびアカウント構造のプロビジョニングと統制を管理します。

```mermaid
graph TD
    Root[AWS Organizations Root]
    Root --> CoreOU[Core / Security OU]
    Root --> WorkloadsOU[Workloads OU]
    
    CoreOU --> Management[Management Account]
    CoreOU --> LogArchive[Log Archive Account]
    CoreOU --> Audit[Audit / Security Account]
    CoreOU --> SharedServices[Shared Services Account]
    
    WorkloadsOU --> Dev[Development Account]
    WorkloadsOU --> Stg[Staging Account]
    WorkloadsOU --> Prod[Production Account]
```

### 📂 管理リソースと構成予定ディレクトリ

- `organizations/` - Organizations 組織構造・OU定義
- `policies/` - 共通ガードレール（SCP: サービスコントロールポリシー）定義
  - 許可リージョン制限（ap-northeast-1 以外でのリソース作成拒否）
  - セキュリティ監査機能（GuardDuty/Security Hub/Config/CloudTrail）の無効化・削除防止
  - 本番データの意図しない削除制限
- `identity/` - AWS IAM Identity Center (SSO) の権限セット・グループ管理
- `shared-services/` - 各環境共通で利用する CI/CD デプロイ用 IAM ロールの設定

---

## 🔗 リポジトリ間連携（ドキュメント駆動）について

本リポジトリは、セキュリティ上、個別ワークロードリポジトリ（`learning-ts-concepts`）と完全に権限境界を分離しています。

インフラ接続情報の同期には、**[shared-outputs.md](https://github.com/shadow-architect-dev/learning-ts-concepts/blob/main/docs/governance/shared-outputs.md)** を介したドキュメント駆動の連携を行います。

```mermaid
sequenceDiagram
    participant LZ_AI as aws-landing-zone AI
    participant Repo as shared-outputs.md (learning-ts-concepts)
    participant App_AI as learning-ts-concepts AI
    
    LZ_AI->>LZ_AI: 1. 本リポジトリから AWS ロール等のプロビジョニングを実行
    LZ_AI->>Repo: 2. 実際のアカウントID / ロールARNを書き込んでプッシュ
    Note over Repo: GitHub Sync
    App_AI->>Repo: 3. 更新された値を自動読み込み
    App_AI->>App_AI: 4. 個別環境へデプロイ実行
```

---

## 🔑 ユーザー側で必要なアクション (Setup & Configuration)

本マルチアカウント環境のテンプレートを実際に AWS 上に展開し運用するには、以下の設定と手動アクションが必要です。

### 1. 接続先 AWS 情報の設定
[config/landing-zone-config.json](file:///c:/Git/aws-landing-zone/config/landing-zone-config.json) を開き、実際の AWS 組織（Organizations）の情報を設定してください。
*   `rootId`: AWS Organizations Root の識別ID（例: `r-abcd`）
*   `accounts`: 各 OU に作成・配置した各 AWS アカウントの 12桁の ID。

### 2. AWS 認証情報のセットアップ
管理（Management）アカウントに対する操作権限を持つ AWS CLI プロファイルを用意します。
```powershell
aws configure
# もしくは環境変数の設定
$env:AWS_PROFILE="my-management-profile"
```

### 3. CDK のブートストラップ (Bootstrap)
管理アカウント、および各メンバーアカウントへ CDK のリソースデプロイ用バケット等を作成します。
```powershell
# 管理アカウントのブートストラップ (ap-northeast-1)
npx cdk bootstrap aws://<Management_Account_ID>/ap-northeast-1
```

### 4. スタックのデプロイ
ベースラインを AWS 組織上に展開します。
```powershell
# 全スタックのデプロイ
npx cdk deploy --all
```

### 5. 個別ワークロード側へのパラメータ同期 (shared-outputs.md)
デプロイ完了後、作成された OIDC 信頼ロールの ARN や アカウントID 等の出力値を、個別ワークロードリポジトリ (`learning-ts-concepts`) の [docs/governance/shared-outputs.md](file:///c:/Git/learning-ts-concepts/docs/governance/shared-outputs.md) に書き込み、コミットしてプッシュしてください。これにより、ワークロード側の CI/CD が自動デプロイ可能になります。

---

## 🚀 開発・運用の進め方

本リポジトリに変更を加える際は、以下のステップを実行します。

1. **ベースラインの合成・検証**:
   - `npm run build` を実行して TypeScript のコンパイルエラーが無いことを確認します。
   - `npx cdk synth` を実行して、出力される CloudFormation 定義（SCP、タグポリシーなど）を検証します。
2. **アカウント作成・変更**:
   - アカウントの払い出しやデプロイ用ロールの追加が完了したら、連携用の `shared-outputs.md` に対して最新の接続パラメータを書き出してマージします。
