variable "environment" {
  type        = string
  description = "Target environment name (e.g., prod, prod-eks)"
}

variable "retention_days" {
  type        = number
  description = "Number of days to retain backups in the vault"
  default     = 7
}

variable "kms_key_arn" {
  type        = string
  description = "Optional KMS key ARN to encrypt the backup vault (falls back to aws/backup if not set)"
  default     = null
}
