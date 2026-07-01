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
}