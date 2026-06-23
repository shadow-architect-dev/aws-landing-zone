# ==============================================================================
# AWS IAM Identity Center Module (Management Account)
# ==============================================================================

variable "sso_instance_arn" { type = string }
variable "accounts" {
  type = object({
    dev      = string
    stg      = string
    prod     = string
    dev_eks  = string
    stg_eks  = string
    prod_eks = string
  })
}
variable "sso_group_ids" {
  type = object({
    admins     = string
    developers = string
    breakGlass = string
  })
}

# ------------------------------------------------------------------------------
# 1. 許可セット (Permission Sets) の定義
# ------------------------------------------------------------------------------

# 1-1. 管理者用許可セット (AdministratorAccess)
resource "aws_ssoadmin_permission_set" "admin" {
  name             = "AdministratorAccessSet"
  description      = "System Administrator Access with full control. Short session duration for security."
  instance_arn     = var.sso_instance_arn
  session_duration = "PT4H"
}

resource "aws_ssoadmin_managed_policy_attachment" "admin_attachment" {
  instance_arn       = var.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
}

# 1-2. 開発用パワーユーザー許可セット (PowerUserAccess)
resource "aws_ssoadmin_permission_set" "power_user" {
  name             = "PowerUserAccessSet"
  description      = "PowerUserAccess equivalent for application developers. Excludes IAM management."
  instance_arn     = var.sso_instance_arn
  session_duration = "PT8H"
}

resource "aws_ssoadmin_managed_policy_attachment" "power_user_attachment" {
  instance_arn       = var.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  permission_set_arn = aws_ssoadmin_permission_set.power_user.arn
}

# 1-3. 閲覧専用許可セット (ReadOnlyAccess)
resource "aws_ssoadmin_permission_set" "read_only" {
  name             = "ReadOnlyAccessSet"
  description      = "ReadOnlyAccess for auditing and normal-time production viewing."
  instance_arn     = var.sso_instance_arn
  session_duration = "PT8H"
}

resource "aws_ssoadmin_managed_policy_attachment" "read_only_attachment" {
  instance_arn       = var.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.read_only.arn
}

# ------------------------------------------------------------------------------
# 2. アカウント割り当て (Account Assignments) の定義
# ------------------------------------------------------------------------------

# --- 管理者グループ (AWS-Admins) の割り当て ---

resource "aws_ssoadmin_account_assignment" "admin_dev" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_id       = var.sso_group_ids.admins
  principal_type     = "GROUP"
  target_id          = var.accounts.dev
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "admin_stg" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_id       = var.sso_group_ids.admins
  principal_type     = "GROUP"
  target_id          = var.accounts.stg
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "admin_prod" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_id       = var.sso_group_ids.admins
  principal_type     = "GROUP"
  target_id          = var.accounts.prod
  target_type        = "AWS_ACCOUNT"
}

# --- 開発者グループ (AWS-Developers) の割り当て ---

resource "aws_ssoadmin_account_assignment" "developer_dev" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.power_user.arn
  principal_id       = var.sso_group_ids.developers
  principal_type     = "GROUP"
  target_id          = var.accounts.dev
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "developer_stg" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.power_user.arn
  principal_id       = var.sso_group_ids.developers
  principal_type     = "GROUP"
  target_id          = var.accounts.stg
  target_type        = "AWS_ACCOUNT"
}

# 本番環境には ReadOnlyAccessSet を付与 (平常時の最小権限)
resource "aws_ssoadmin_account_assignment" "developer_prod_readonly" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read_only.arn
  principal_id       = var.sso_group_ids.developers
  principal_type     = "GROUP"
  target_id          = var.accounts.prod
  target_type        = "AWS_ACCOUNT"
}

# --- 緊急作業グループ (AWS-BreakGlass) の割り当て ---

# 本番環境に対して一時的に特権管理者権限を許可
resource "aws_ssoadmin_account_assignment" "breakglass_prod" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_id       = var.sso_group_ids.breakGlass
  principal_type     = "GROUP"
  target_id          = var.accounts.prod
  target_type        = "AWS_ACCOUNT"
}

# --- EKS 新規ワークロード用のアカウント割り当て ---

# 開発グループ (aws-dev-group) ➔ EKS Dev (DeveloperPermissionSet = power_user)
resource "aws_ssoadmin_account_assignment" "developer_eks_dev" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.power_user.arn
  principal_id       = var.sso_group_ids.developers
  principal_type     = "GROUP"
  target_id          = var.accounts.dev_eks
  target_type        = "AWS_ACCOUNT"
}

# 開発グループ (aws-dev-group) ➔ EKS Stg (ReadOnlyPermissionSet = read_only)
resource "aws_ssoadmin_account_assignment" "developer_eks_stg_readonly" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read_only.arn
  principal_id       = var.sso_group_ids.developers
  principal_type     = "GROUP"
  target_id          = var.accounts.stg_eks
  target_type        = "AWS_ACCOUNT"
}

# 開発グループ (aws-dev-group) ➔ EKS Prod (ReadOnlyPermissionSet = read_only)
resource "aws_ssoadmin_account_assignment" "developer_eks_prod_readonly" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read_only.arn
  principal_id       = var.sso_group_ids.developers
  principal_type     = "GROUP"
  target_id          = var.accounts.prod_eks
  target_type        = "AWS_ACCOUNT"
}

# 緊急対応グループ (aws-ops-group / breakGlass) ➔ EKS Prod (BreakGlassPermissionSet = admin)
resource "aws_ssoadmin_account_assignment" "breakglass_eks_prod" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_id       = var.sso_group_ids.breakGlass
  principal_type     = "GROUP"
  target_id          = var.accounts.prod_eks
  target_type        = "AWS_ACCOUNT"
}
