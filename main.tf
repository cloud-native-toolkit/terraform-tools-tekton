provider "helm" {
  version = ">= 1.1.1"

  kubernetes {
    config_path = var.cluster_config_file_path
  }
}

provider "null" {
}

locals {
  tmp_dir             = "${path.cwd}/.tmp"
  dashboard_namespace = var.cluster_type == "ocp4" ? "openshift-pipelines" : "tekton-pipelines"
  dashboard_file      = var.cluster_type == "ocp4" ? var.tekton_dashboard_yaml_file_ocp : var.tekton_dashboard_yaml_file_k8s
  ingress_host        = "tekton-dashboard-${local.dashboard_namespace}.${var.cluster_ingress_hostname}"
  gitops_dir          = var.gitops_dir != "" ? var.gitops_dir : "${path.cwd}/gitops"
  chart_name          = "tekton"
  chart_dir           = "${local.gitops_dir}/${local.chart_name}"
  global_config       = {
    clusterType = var.cluster_type
    ingressSubdomain = var.cluster_ingress_hostname
  }
  tekton_operator_config  = {
    olmNamespace = var.olm_namespace
    operatorNamespace = var.operator_namespace
    app = "tekton"
  }
  tool_config = {
    url = "https://${local.ingress_host}"
    applicationMenu = false
  }
}

resource "null_resource" "setup-chart" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.chart_dir} && cp -R ${path.module}/chart/${local.chart_name}/* ${local.chart_dir}"
  }
}

resource "null_resource" "download-tekton-dashboard-yaml" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.chart_dir}/templates && curl -L -o ${local.chart_dir}/templates/${local.dashboard_file} https://github.com/tektoncd/dashboard/releases/download/${var.tekton_dashboard_version}/${local.dashboard_file}"
  }
}

resource "local_file" "tekton-values" {
  depends_on = [null_resource.setup-chart, null_resource.download-tekton-dashboard-yaml]

  content  = yamlencode({
    global = local.global_config
    tekton-operator = local.tekton_operator_config
    tool-config = local.tool_config
  })
  filename = "${local.chart_dir}/values.yaml"
}

resource "null_resource" "print-values" {
  provisioner "local-exec" {
    command = "cat ${local_file.tekton-values.filename}"
  }
}

resource "helm_release" "tekton" {
  depends_on = [local_file.tekton-values]
  count = var.mode != "setup" && var.cluster_type == "ocp4" ? 1 : 0

  name              = "tekton"
  chart             = local.chart_dir
  namespace         = var.tools_namespace
  timeout           = 1200
  dependency_update = true
  force_update      = true
  replace           = true

  disable_openapi_validation = true
}
