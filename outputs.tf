output "namespace" {
  description = "The namespace where Tekton dashboard was deployed"
  value       = var.tekton_dashboard_namespace
  depends_on  = [data.external.tekton_ready]
}
