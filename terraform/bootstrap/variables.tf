# ==============================================================================
# Terraform Backend Bootstrap Variables
# ==============================================================================

variable "region" {
  type        = string
  description = "AWS deployment region for backend resources"
  default     = "ap-northeast-1"
}

variable "management_account_id" {
  type        = string
  description = "AWS Management Account ID"
  default     = "111122223333"
}
