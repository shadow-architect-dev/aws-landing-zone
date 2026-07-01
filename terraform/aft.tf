# ==============================================================================
# AWS Control Tower AFT (Account Factory for Terraform) Deployment
# ==============================================================================

# AFT は管理アカウント (aws.management) でデプロイを実行し、各役割アカウントを指定して連携します
module "control_tower_aft" {
  source  = "aws-ia/control_tower_account_factory/aws"
  version = "1.15.0"

  # AWS Organizations ＆ 各種アカウントIDのパラメータ指定
  ct_management_account_id  = var.accounts.management
  log_archive_account_id    = var.accounts.logArchive
  audit_account_id          = var.accounts.audit
  aft_management_account_id = var.accounts.aft_management
  ct_home_region            = var.region

  # AFT バックエンド用のセカンダリリージョン (S3 レプリケーション等のディザスタリカバリ用)
  tf_backend_secondary_region = "us-east-1"

  # リポジトリプロバイダーの定義 (GitHub連携 / OIDC信頼関係)
  vcs_provider = "github"

  # AFT のオーケストレーションに使用する GitHub 4 リポジトリ連携
  # (owner/repository_name フォーマットで指定)
  account_request_repo_name                     = "${var.github_owner}/aws-landing-zone-aft-account-requests"
  global_customizations_repo_name               = "${var.github_owner}/aws-landing-zone-aft-global-customizations"
  account_customizations_repo_name              = "${var.github_owner}/aws-landing-zone-aft-account-customizations"
  account_provisioning_customizations_repo_name = "${var.github_owner}/aws-landing-zone-aft-account-provisioning-customizations"

  # ----------------------------------------------------------------------------
  # コスト最適化 ＆ ネットワーク設計 (SREベストプラクティス)
  # ----------------------------------------------------------------------------
  # デフォルトの VPC を自動構築させ、コスト削減のためプライベート VPC エンドポイントを無効化
  aft_vpc_endpoints = false

  # AFT 実行用の VPC の CIDR 定義 (既存の VPC アドレス空間との競合防止)
  aft_vpc_cidr = "10.120.0.0/16"

  # Terraform 動作設定のカスタマイズ
  terraform_distribution = "oss" # オープンソース版 Terraform
}
