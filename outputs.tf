output "namespace" {
  description = "The namespace where Tekton dashboard was deployed"
  value       = var.tekton_dashboard_namespace
  depends_on  = [null_resource.tekton_ready]
}

output "tekton_namespace" {
  description = "The namespace where Tekton dashboard was deployed"
  value       = var.tekton_dashboard_namespace
  depends_on  = [null_resource.tekton_ready]
}

output "skip" {
  description = "Flag indicating that install was skipped because another version was already installed"
  value       = data.external.check_for_operator.result.exists == "true"
}

output "exists" {
  description = "Flag indicating that install was skipped because another version was already installed"
  value       = data.external.check_for_operator.result.exists
}
