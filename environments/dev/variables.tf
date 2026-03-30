variable "db_username" {
  type        = string
  description = "Database username"
  default     = "dbadmin"
}

variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
  default     = "Password123!"
}