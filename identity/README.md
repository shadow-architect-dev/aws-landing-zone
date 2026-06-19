# AWS IAM Identity Center (SSO) 設計

AWS IAM Identity Center (旧 AWS Single Sign-On) を使用して、マルチアカウント環境への安全なフェデレーションアクセスとユーザー権限の集中管理を行います。

## 権限割り当て設計 (Group & Permission Set Mapping)

以下は、組織で定義する標準的なグループ、権限セット、および各アカウントへのマッピング定義です。

| グループ名 | 権限セット名 (Permission Set) | 割り当て対象アカウント/OU | 説明 |
| :--- | :--- | :--- | :--- |
| **AWS-Admins** | `AdministratorAccess` | 全アカウント | 全リソースに対するフル管理権限を持つシステム管理者グループ。二要素認証（MFA）を必須とします。 |
| **AWS-SecurityAuditors** | `SecurityAudit` | 全アカウント | セキュリティ監視・監査担当用グループ。Security Hub, GuardDuty 等の監査ログや構成情報を閲覧可能。 |
| **AWS-Developers** | `PowerUserAccess` | `Dev` (Development) | 開発者用グループ。Dev アカウント内での主要サービス（EC2, RDS, Lambda, S3等）の作成・編集を許可。IAM操作は不可。 |
| | `ReadOnlyAccess` | `Stg`, `Prod` | ステージング・本番環境に対しては、閲覧のみ可能な読込専用権限を付与。 |
| **AWS-Operators** | `ViewOnlyAccess` + サポート閲覧 | `Prod` | システム運用担当用グループ。ダッシュボードやメトリクス、サポートチケットへのアクセスのみ許可。 |

## 権限セット定義 (Permission Sets Details)

1. **AdministratorAccess (管理者権限)**:
   - AWS 管理ポリシー: `arn:aws:iam::aws:policy/AdministratorAccess`
2. **PowerUserAccess (開発用パワーユーザー権限)**:
   - AWS 管理ポリシー: `arn:aws:iam::aws:policy/PowerUserAccess`
3. **ReadOnlyAccess (閲覧者権限)**:
   - AWS 管理ポリシー: `arn:aws:iam::aws:policy/ReadOnlyAccess`
4. **SecurityAudit (監査者権限)**:
   - AWS 管理ポリシー: `arn:aws:iam::aws:policy/SecurityAudit`

## 運用方針
- 権限セットのプロビジョニングは原則として CDK (`IdentityStack`) を用いてコード管理します。
- ユーザーのグループへの追加・削除は、Identity Center のユーザーディレクトリ（または外部 IdP）側で行い、IAM ロールの直接アタッチは禁止します。
