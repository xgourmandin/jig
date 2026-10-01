variable "db_password" {
  type        = string
  description = "Admin password, from the pipeline secret store."
  sensitive   = true
}

variable "token_ttl_seconds" {
  type        = number
  description = "Token lifetime."
  default     = 3600
}

variable "db_password_secret_arn" {
  type        = string
  description = "Secrets Manager entry holding the password."
}

variable "license_key_wo" {
  type        = string
  description = "Write-only license."
  ephemeral   = true
}
