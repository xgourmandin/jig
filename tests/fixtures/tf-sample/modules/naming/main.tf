terraform {
  required_version = ">= 1.9"
}

variable "prefix" {
  description = "Name prefix."
  type        = string
}

variable "name" {
  description = "Base name."
  type        = string
}

output "full_name" {
  description = "Prefix and name joined with a dash."
  value       = "${var.prefix}-${var.name}"
}
