# Postgres Variables
variable "postgres_db" {
  type = string
  description = "Default postgres database name"
  default = "postgres"
}

variable "postgres_user" {
  type = string
  description = "Postgres admin user"
  nullable = false
}

variable "postgres_password" {
  type = string
  description = "Postgres admin password"
  nullable = false
}