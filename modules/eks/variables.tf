variable "public_subnet" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "private_subnet" {
  description = "Private subnet IDs"
  type        = list(string)
}