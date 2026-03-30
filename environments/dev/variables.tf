variable "db_username" {
  type        = string
  description = "Database username"
  default     = "admin"
}

variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
  default     = "Password@123"
}