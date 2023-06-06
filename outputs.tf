output "namespace" {
  description = "The namespace where Tekton dashboard was deployed"
  value       = local.operator_namespace
  depends_on  = [null_resource.tekton_ready]
}

output "operator_namespace" {
  description = "The namespace where the subscription for the Tekton operator was created"
  value       = local.operator_namespace
  depends_on  = [null_resource.tekton_ready]
}

output "operator_name" {
  description = "The name of the subscription for the Tekton operator"
  value       = data.external.get_operator_config.result.packageName
  depends_on  = [null_resource.tekton_ready]
}

output "subscription_name" {
  description = "The name of the subscription for the Tekton operator"
  value       = data.external.get_operator_config.result.packageName
  depends_on  = [null_resource.tekton_ready]
}

output "tekton_namespace" {
  description = "The namespace where Tekton dashboard was deployed"
  value       = local.dashboard_namespace
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
