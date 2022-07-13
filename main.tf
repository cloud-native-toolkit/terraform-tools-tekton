
locals {
  tmp_dir             = "${path.cwd}/.tmp/tekton"
  cluster_type        = data.external.cluster_info.result.clusterType
  cluster_version     = data.external.cluster_info.result.clusterVersion
  console_host        = data.external.cluster_info.result.consoleHost
  dashboard_namespace = local.cluster_type == "ocp4" ? "openshift-pipelines" : "tekton-pipelines"
  ingress_url         = local.cluster_type == "ocp4" ? "https://${local.console_host}/k8s/all-namespaces/tekton.dev~v1alpha1~Pipeline" : ""
  chart_name          = "tekton"
  chart_dir           = "${path.module}/chart/${local.chart_name}"
  created_by          = "tekton-${random_string.random.result}"
  global_config       = {
    enabled = var.provision
    clusterType = local.cluster_type
    ingressSubdomain = var.cluster_ingress_hostname
  }
  tekton_operator_config  = {
    clusterType = local.cluster_type
    olmNamespace = var.olm_namespace
    operatorNamespace = var.operator_namespace
    createdBy = local.created_by
    app = "tekton"
    ocpCatalog = {
      channel = "stable"
    }
  }
  tool_config = {
    url = local.ingress_url
    name = "Tekton"
    applicationMenu = false
    enableConsoleLink = false
  }
}

module setup_clis {
  source = "github.com/cloud-native-toolkit/terraform-util-clis.git"

  clis = ["jq", "oc", "kubectl", "helm"]
}

resource "random_string" "random" {
  length           = 16
  lower            = true
  number           = true
  upper            = false
  special          = false
}

data external cluster_info {
  program = ["bash", "${path.module}/scripts/get-cluster-info.sh"]

  query = {
    bin_dir     = module.setup_clis.bin_dir
    kube_config = var.cluster_config_file_path
  }
}

data external check_for_operator {
  program = ["bash", "${path.module}/scripts/check-for-operator.sh"]

  query = {
    kube_config = var.cluster_config_file_path
    namespace = var.operator_namespace
    bin_dir = module.setup_clis.bin_dir
    created_by = local.created_by
  }
}

resource null_resource tekton_operator_helm {

  triggers = {
    namespace = var.operator_namespace
    name = "tekton"
    chart = local.chart_dir
    values_file_content = yamlencode({
      global = local.global_config
      tekton-operator = local.tekton_operator_config
      tool-config = local.tool_config
    })
    kubeconfig = var.cluster_config_file_path
    tmp_dir = local.tmp_dir
    bin_dir = module.setup_clis.bin_dir
    created_by = local.created_by
    skip = data.external.check_for_operator.result.exists
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh '${self.triggers.namespace}' '${self.triggers.name}' '${self.triggers.chart}'"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
      CREATED_BY = self.triggers.created_by
      SKIP = self.triggers.skip
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-operator.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
      CREATED_BY = self.triggers.created_by
      SKIP = self.triggers.skip
    }
  }
}

resource null_resource tekton_ready {
  depends_on = [null_resource.tekton_operator_helm]

  provisioner "local-exec" {
    command = "echo \"$INPUT\" | ${path.module}/scripts/wait-for-tekton.sh"

    environment = {
      INPUT = jsonencode({
        bin_dir = module.setup_clis.bin_dir
        cluster_version = local.cluster_version
        namespace = var.operator_namespace
        cluster_type = local.cluster_type
        kube_config = var.cluster_config_file_path
        skip = data.external.check_for_operator.result.exists
      })
    }
  }
}
