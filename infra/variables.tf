variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "rds_username" {
  description = "Master username for the PostgreSQL RDS instance"
  type        = string
  # \"admin\" is a reserved word for PostgreSQL; use a non‑reserved name
  default     = "postgres"
}

variable "rds_password" {
  description = "Master password for the PostgreSQL RDS instance"
  type        = string
  sensitive   = true
}
