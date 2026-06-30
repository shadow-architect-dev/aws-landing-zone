# ==============================================================================
# AWS Shared Services Module (Management Account / GitHub Actions OIDC)
# ==============================================================================

variable "github_repo" { type = string }
variable "region" { type = string }
variable "accounts" {
  type = object({
    management     = string
    logArchive     = string
    audit          = string
    sharedServices = string
    dev            = string
    stg            = string
    prod           = string
    dev_eks        = string
    stg_eks        = string
    prod_eks       = string
  })
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR for Shared Services VPC"
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "Target Availability Zones"
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "single_nat_gateway" {
  type        = bool
  description = "Enable single NAT Gateway for cost saving in non-prod"
  default     = true
}

# ------------------------------------------------------------------------------
# 1. GitHub Actions 用の OIDC プロバイダーを作成
# ------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub OIDC Thumbprint
}

# ------------------------------------------------------------------------------
# 2. GitHub Actions デプロイ用 IAM ロール
# ------------------------------------------------------------------------------

resource "aws_iam_role" "github_deploy" {
  name                 = "GitHubActionsWorkflowDeployRole"
  description          = "Deployment role assumed by GitHub Actions for repository: ${var.github_repo}"
  max_session_duration = 7200 # 2時間

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repo}:ref:refs/heads/main",
              "repo:${var.github_repo}:ref:refs/heads/develop",
              "repo:${var.github_repo}:ref:refs/heads/release/*"
            ]
          }
        }
      }
    ]
  })
}

# デプロイ用に管理者権限ポリシーを付与
resource "aws_iam_role_policy_attachment" "github_deploy_admin" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ------------------------------------------------------------------------------
# 3. AWS Transit Gateway (TGW) & AWS RAM for Cross-Account Sharing
# ------------------------------------------------------------------------------

locals {
  spoke_accounts = [
    var.accounts.dev,
    var.accounts.stg,
    var.accounts.prod,
    var.accounts.dev_eks,
    var.accounts.stg_eks,
    var.accounts.prod_eks
  ]
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "Landing Zone Shared Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments  = "enable"

  tags = {
    Name = "landingzone-shared-tgw"
  }
}

# AWS RAM Resource Share
resource "aws_ram_resource_share" "tgw_share" {
  name                      = "transit-gateway-share"
  allow_external_principals = false
}

# Associate TGW with RAM
resource "aws_ram_resource_association" "tgw_association" {
  resource_arn       = aws_ec2_transit_gateway.tgw.arn
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}

# Associate Spoke Accounts as Principals
resource "aws_ram_principal_association" "tgw_principals" {
  count              = length(local.spoke_accounts)
  principal          = local.spoke_accounts[count.index]
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}

# ------------------------------------------------------------------------------
# 4. AWS VPC IPAM (IP Address Manager) & IPAM Pool
# ------------------------------------------------------------------------------

# IPAM 本体
resource "aws_vpc_ipam" "main" {
  description = "Landing Zone Global IP Address Manager"

  operating_regions {
    region_name = var.region
  }

  tags = {
    Name = "landingzone-global-ipam"
  }
}

# 親 IPAM プール
resource "aws_vpc_ipam_pool" "parent" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.main.private_default_scope_id
  description    = "Landing Zone Parent IPAM Pool"

  tags = {
    Name = "landingzone-parent-pool"
  }
}

# 親 IPAM プールに大元の CIDR (10.0.0.0/8) を割り当て
resource "aws_vpc_ipam_pool_cidr" "parent_cidr" {
  ipam_pool_id = aws_vpc_ipam_pool.parent.id
  cidr         = "10.0.0.0/8"
}

# IPAM プール共有用の AWS RAM Resource Share
resource "aws_ram_resource_share" "ipam_share" {
  name                      = "ipam-pool-share"
  allow_external_principals = false

  tags = {
    Name = "ipam-pool-share"
  }
}

# IPAM プールを RAM に関連付け
resource "aws_ram_resource_association" "ipam_association" {
  resource_arn       = aws_vpc_ipam_pool.parent.arn
  resource_share_arn = aws_ram_resource_share.ipam_share.arn
}

# 共有先アカウントへの RAM プリンシパル関連付け
resource "aws_ram_principal_association" "ipam_principals" {
  count              = length(local.spoke_accounts)
  principal          = local.spoke_accounts[count.index]
  resource_share_arn = aws_ram_resource_share.ipam_share.arn
}

# ------------------------------------------------------------------------------
# 5. Shared Services Centralized VPC (Hub)
# ------------------------------------------------------------------------------

resource "aws_vpc" "shared" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "landingzone-shared-services-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.shared.id

  tags = {
    Name = "landingzone-shared-services-igw"
  }
}

# Public Subnets (for NAT Gateway placements)
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.shared.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "shared-public-subnet-${var.azs[count.index]}"
  }
}

# Private Subnets (for TGW Attachment placements)
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.shared.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "shared-private-subnet-${var.azs[count.index]}"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.azs)
  domain = "vpc"

  tags = {
    Name = "shared-nat-eip-${count.index}"
  }
}

# NAT Gateway (Central Outbound Gateway)
resource "aws_nat_gateway" "nat" {
  count         = var.single_nat_gateway ? 1 : length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "shared-nat-gateway-${count.index}"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.shared.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "shared-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.shared.id

  # 集約デフォルトルート (インターネット宛ては NAT GW へ)
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[var.single_nat_gateway ? 0 : count.index].id
  }

  # リターンルート (Spoke宛ては TGW へ)
  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "shared-private-rt-${var.azs[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ------------------------------------------------------------------------------
# 6. Transit Gateway VPC Attachment (Shared Services VPC)
# ------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "shared_services" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.shared.id
  subnet_ids         = aws_subnet.private[*].id

  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = {
    Name = "shared-services-tgw-attachment"
  }
}

# TGW のデフォルトルートテーブルに 0.0.0.0/0 (Egress) を追加し、Shared Services VPC へ流す
resource "aws_ec2_transit_gateway_route" "default_egress" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tgw.association_default_route_table_id
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}

output "tgw_id" {
  value       = aws_ec2_transit_gateway.tgw.id
  description = "ID of the shared Transit Gateway"
}

output "tgw_arn" {
  value       = aws_ec2_transit_gateway.tgw.arn
  description = "ARN of the shared Transit Gateway"
}

output "ipam_pool_id" {
  value       = aws_vpc_ipam_pool.parent.id
  description = "ID of the shared parent IPAM pool"
}
