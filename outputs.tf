output "namespace" {
  description = "The namespace where Tekton dashboard was deployed"
  value       = var.tekton_dashboard_namespace
  depends_on  = [helm_release.tekton]
}

