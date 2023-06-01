
# Cluster Variables
variable "cluster_config_file_path" {
  type        = string
  description = "The path to the config file for the cluster"
}

variable "cluster_ingress_hostname" {
  type        = string
  description = "Ingress hostname of the IKS cluster."
}

variable "olm_namespace" {
  type        = string
  description = "Namespace where olm is installed"
  default     = ""
}

variable "operator_namespace" {
  type        = string
  description = "Namespace where operators will be installed"
  default     = "openshift-operators"
}

variable "provision" {
  type        = bool
  description = "Flag indicating that Tekton should be provisioned"
  default     = true
}
