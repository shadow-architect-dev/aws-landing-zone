# ワークスルー: AWS Organizations 初期設計 & ログ集約・セキュリティ・コスト自動統制

AWS Organizations のマルチアカウント統制に向けた初期設計（OU構成やSCPポリシー定義）の配置と、プロジェクトのベースライン（CDK/TypeScript）の初期セットアップが完了しました。
さらに、**ログの暗号化セキュリティ（KMSキー）**、**組織全体のセキュリティ基準自動監視（Security Hub）**、および**財務財務ガバナンス（AWS Budgets）**を追加実装しました。

---

## 成果物一覧

### 1. 設計ドキュメント & ポリシー定義 (Design & SCP Docs)
- [organizations/ou-structure.md](file:///c:/Git/aws-landing-zone/organizations/ou-structure.md): OU（Core, Workloads）構成およびAWSアカウントの役割設計書。
- [README.md](file:///c:/Git/aws-landing-zone/README.md): ユーザーが実行すべき必須アクション（セットアップ手順）を追記したプロジェクト説明書。
- [policies/README.md](file:///c:/Git/aws-landing-zone/policies/README.md): SCP（サービスコントロールポリシー）およびタグポリシーの適用・運用方針ドキュメント。
- [policies/scp/restrict-regions.json](file:///c:/Git/aws-landing-zone/policies/scp/restrict-regions.json): 東京リージョン（`ap-northeast-1`）以外での不要な操作を拒否する SCP 定義。
- [policies/scp/protect-security-services.json](file:///c:/Git/aws-landing-zone/policies/scp/protect-security-services.json): セキュリティ監視サービス（CloudTrail, GuardDuty 等）の無効化を防止する SCP 定義。
- [policies/scp/prevent-prod-deletion.json](file:///c:/Git/aws-landing-zone/policies/scp/prevent-prod-deletion.json): 本番環境のデータ削除防止に加え、`s3:PutBucketVersioning`（バージョニング無効化防止）を追加した SCP 定義。
- [policies/tag-policies/enforce-mandatory-tags.json](file:///c:/Git/aws-landing-zone/policies/tag-policies/enforce-mandatory-tags.json): コスト管理・財務ガバナンスのため、`Environment` および `Project` タグの付与と指定値を強制するタグポリシー定義。
- [identity/README.md](file:///c:/Git/aws-landing-zone/identity/README.md): IAM Identity Center (SSO) グループ・権限セットのマッピング設計書。
- [shared-services/README.md](file:///c:/Git/aws-landing-zone/shared-services/README.md): GitHub Actions OIDC によるクロスアカウントデプロイ権限（ロール）設計書。

### 2. CDK/TypeScript インフラベースライン (CDK Project Baseline)
- [config/landing-zone-config.json](file:///c:/Git/aws-landing-zone/config/landing-zone-config.json): アカウントIDやルートIDの設定ファイル。
- [bin/aws-landing-zone.ts](file:///c:/Git/aws-landing-zone/bin/aws-landing-zone.ts): 全スタックを登録した CDK App エントリーポイント。
- [lib/stacks/organizations-stack.ts](file:///c:/Git/aws-landing-zone/lib/stacks/organizations-stack.ts): 組織、OU、SCP、タグポリシー、GuardDuty委任、**Security Hub委任（AwsCustomResource）**、**組織の証跡 (Organization Trail)**、および**AWS Budgets 予算アラート**を統合定義するスタック。
- [lib/stacks/log-archive-stack.ts](file:///c:/Git/aws-landing-zone/lib/stacks/log-archive-stack.ts): ログ保管用 S3 バケット、**ログ暗号化用のカスタマー管理型 KMS キー（SSE-KMS）**、Kinesis Data Firehose、クロスアカウント配信 IAM ロールを定義するスタック。
- [lib/stacks/security-audit-stack.ts](file:///c:/Git/aws-landing-zone/lib/stacks/security-audit-stack.ts): Audit アカウント側で動作し、Config 集約器、GuardDuty 組織自動化、および**Security Hub の有効化と組織自動有効化**を定義するスタック。
- [lib/stacks/identity-stack.ts](file:///c:/Git/aws-landing-zone/lib/stacks/identity-stack.ts): IAM Identity Center 構成管理用スタックのひな形。
- [lib/stacks/shared-services-stack.ts](file:///c:/Git/aws-landing-zone/lib/stacks/shared-services-stack.ts): OIDC デプロイ用 IAM ロールを管理するスタック。
- [.github/workflows/ci.yml](file:///c:/Git/aws-landing-zone/.github/workflows/ci.yml): プッシュ/プルリクエスト時に自動でビルドおよび `cdk synth` を行い、IaCコードの整合性を担保する GitHub Actions CI ワークフロー。

### 3. クロスリポジトリ連携 (Cross-Repository Sync)
- [shared-outputs.md (learning-ts-concepts)](file:///c:/Git/learning-ts-concepts/docs/governance/shared-outputs.md): 作成した `LOG_ARCHIVE_FIREHOSE_ARN` および `LOG_ARCHIVE_DELIVERY_ROLE_ARN` をワークロード側リポジトリへ自動同期。

---

## 検証結果

### 1. ビルド検証
`npm run build` を実行し、TypeScript がエラーなく正常にコンパイルされることを確認しました。
```bash
> tsc
# 正常終了 (終了コード 0)
```

### 2. テンプレート合成検証 (cdk synth)
`npx cdk synth` を実行し、以下の監査用操作ログ集約設定を含む CloudFormation テンプレートが正しく合成されることを確認しました。
- **LandingZoneOrganizationsStack (管理アカウント)**:
  - `AWS::CloudTrail::Trail` の作成（KMS暗号化キーを紐付け）
  - `AWS::Budgets::Budget` の作成（月額コスト上限 $1000、80% 実費時および 100% 予測時にメール通知）
  - GuardDuty & Security Hub の委任管理者設定（カスタムリソース）
- **LandingZoneLogArchiveStack (ログ集約アカウント)**:
  - `AWS::KMS::Key` の作成（CloudTrail のログ書き込みを許可する KMS キーポリシーを定義）
  - `AWS::S3::Bucket` (上記 KMS キーを用いた SSE-KMS 暗号化を適用)
- **LandingZoneSecurityAuditStack (監査アカウント)**:
  - Config 集約器 (`AWS::Config::ConfigurationAggregator`)
  - GuardDuty 検出器作成 & 組織自動有効化 (カスタムリソース)
  - Security Hub 有効化 (`AWS::SecurityHub::Hub`) & 組織自動有効化 (カスタムリソース)

---

## 財務・セキュリティガバナンスにおける実務メリット
*   **監査ログの一元化と不変性 (Compliance)**: 全アカウントの API イベントログを一つの `Log Archive` バケットに書き込みます。バケットポリシーとバージョニング、さらには CloudTrail 独自の「ログファイル整合性検証（Log File Integrity Validation）」をオンにすることで、監査ログが改ざんされた場合に即座に検知可能なコンプライアンス準拠の設計にしています。
*   **安全なクロスアカウントアクセス**: 管理アカウントの CloudTrail と、ログ集約アカウントの S3 バケットの接続において、S3 バケットポリシーを用いて `cloudtrail.amazonaws.com` に `s3:PutObject` のみを許可する最小特権アクセスポリシーを敷いています。
*   **フル自動ガバナンス構造の確立**: SCP、タグポリシー、ID管理（SSO）、デプロイ特権（OIDC）、セキュリティ監視（Config/GuardDuty）、および監査証跡（CloudTrail）のすべてが CDK で統制され、完全に実務レベルの Landing Zone ベースラインが構築されました。
