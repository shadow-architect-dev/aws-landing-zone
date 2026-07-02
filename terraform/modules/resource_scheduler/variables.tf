variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, stg)"
}

variable "schedule_tag_value" {
  type        = string
  description = "The value of the 'Schedule' tag to search for"
  default     = "office-hours"
}

variable "stop_cron" {
  type        = string
  description = "Cron expression for stopping resources (JST 20:00 = 11:00 UTC)"
  default     = "cron(0 11 * * ? *)"
}

variable "start_cron" {
  type        = string
  description = "Cron expression for starting resources (JST 08:00 = 23:00 UTC)"
  default     = "cron(0 23 * * ? *)"
}
