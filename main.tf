provider "helm" {
  version = ">= 1.1.1"

  kubernetes {
    config_path = var.cluster_config_file_path
  }
}

provider "null" {
}

locals {
  tmp_dir      = "${path.cwd}/.tmp"
  ingress_host = "tekton-${var.tools_namespace}.${var.cluster_ingress_hostname}"
}

resource "null_resource" "tekton" {
  count      = var.cluster_type == "ocp4" ? 1 : 0

  triggers = {
    kubeconfig = var.cluster_config_file_path
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-tekton.sh"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR    = local.tmp_dir
    }
  }
}

resource "null_resource" "tekton_dashboard" {
  count      = var.cluster_type == "ocp4" ? 1 : 0
  depends_on = [null_resource.tekton]

  triggers = {
    kubeconfig = var.cluster_config_file_path
    cluster_type = var.cluster_type
    dashboard_namespace = var.tekton_dashboard_namespace
    dashboard_version = var.tekton_dashboard_version
    dashboard_yaml_file_ocp = var.tekton_dashboard_yaml_file_ocp
    dashboard_yaml_file_k8s = var.tekton_dashboard_yaml_file_k8s
    tmp_dir = local.tmp_dir
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-tekton-dashboard.sh ${self.triggers.dashboard_namespace} ${self.triggers.dashboard_version} ${self.triggers.cluster_type} ${self.triggers.dashboard_yaml_file_k8s} ${self.triggers.dashboard_yaml_file_ocp}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR    = self.triggers.tmp_dir
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/destroy-tekton-dashboard.sh ${self.triggers.dashboard_namespace} ${self.triggers.dashboard_version} ${self.triggers.cluster_type} ${self.triggers.dashboard_yaml_file_k8s} ${self.triggers.dashboard_yaml_file_ocp}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR    = self.triggers.tmp_dir
    }
  }
}

resource "helm_release" "tekton-config" {
  count      = var.cluster_type == "ocp4" ? 1 : 0
  depends_on = [null_resource.tekton_dashboard]

  name         = "tekton"
  repository   = "https://ibm-garage-cloud.github.io/toolkit-charts/"
  chart        = "tool-config"
  namespace    = var.tools_namespace
  force_update = true

  set {
    name  = "url"
    value = "https://${local.ingress_host}"
  }
}

resource "null_resource" "copy_cloud_configmap" {
  count      = var.cluster_type == "ocp4" ? 1 : 0
  depends_on = [helm_release.tekton-config]

  triggers = {
    kubeconfig         = var.cluster_config_file_path
    tools_namespace    = var.tools_namespace
    dashboard_namespace = var.tekton_dashboard_namespace
    tmp_dir = local.tmp_dir
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/copy-configmap-to-namespace.sh tekton-config ${self.triggers.tools_namespace}  ${self.triggers.dashboard_namespace}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR    = self.triggers.tmp_dir
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/destroy-tekton-configmap-tools.sh tekton-config ${self.triggers.tools_namespace}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      TMP_DIR    = self.triggers.tmp_dir
    }
  }
}
