variable "db_password" {
  type        = string
  description = "Admin password."
  sensitive   = true
  default     = "changeme"
}
