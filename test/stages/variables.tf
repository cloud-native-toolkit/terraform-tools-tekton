
variable "namespace" {
  type        = string
  description = "Namespace for tools"
}

variable "server_url" {
}

variable "ingress_subdomain" {
  default = ""
}

variable "cluster_username" {
}

variable "cluster_password" {
}
