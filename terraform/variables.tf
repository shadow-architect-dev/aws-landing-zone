variable "region" {
  type        = string
  description = "AWS Deployment Region"
  default     = "ap-northeast-1"
}

variable "root_id" {
  type        = string
  description = "AWS Organizations Root ID"
  default     = "r-placeholder"
}

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
    aft_management = string
  })
  description = "AWS Account IDs"
  default = {
    management     = "111122223333"
    logArchive     = "222222222222"
    audit          = "333333333333"
    sharedServices = "444444444444"
    dev            = "555555555555"
    stg            = "666666666666"
    prod           = "777777777777"
    dev_eks        = "888888888888"
    stg_eks        = "999999999999"
    prod_eks       = "101010101010"
    aft_management = "121212121212"
  }
}

variable "sso_instance_arn" {
  type        = string
  description = "AWS IAM Identity Center Instance ARN"
  default     = "arn:aws:sso:::instance/ssoins-1111222233334444"
}

variable "sso_group_ids" {
  type = object({
    admins     = string
    developers = string
    breakGlass = string
  })
  description = "AWS IAM Identity Center Synced Group IDs"
  default = {
    admins     = "g-0000000000-admins-placeholder"
    developers = "g-1111111111-developers-placeholder"
    breakGlass = "g-2222222222-breakglass-placeholder"
  }
}

variable "control_tower" {
  type = object({
    productId              = string
    provisioningArtifactId = string
  })
  description = "Control Tower Account Factory Product & Artifact IDs"
  default = {
    productId              = "prod-control-tower-product-placeholder"
    provisioningArtifactId = "pa-control-tower-artifact-placeholder"
  }
}

variable "github_repo" {
  type        = string
  description = "GitHub repository for OIDC trust role"
  default     = "shadow-architect-dev/learning-ts-concepts"
}

variable "github_eks_repo" {
  type        = string
  description = "GitHub repository for EKS project OIDC trust role"
  default     = "YOUR_ORGANIZATION/aws-eks-three-tier"
}

variable "datadog_external_id" {
  type        = string
  description = "External ID provided by Datadog AWS Integration page"
  default     = "datadog-external-id-placeholder"
}

variable "github_owner" {
  type        = string
  description = "GitHub Org or Username for AFT GitOps repositories"
  default     = "shadow-architect-dev"
}
