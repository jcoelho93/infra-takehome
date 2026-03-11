variable "postgres_password" {
  description = "Password for the PostgreSQL instance"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "postgres_port" {
  description = "Host port to expose PostgreSQL on"
  type        = number
  default     = 5432
}
