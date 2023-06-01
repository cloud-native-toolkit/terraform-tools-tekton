
locals {
  tmp_dir             = "${path.cwd}/.tmp/tekton"
  bin_dir             = data.clis_check.clis.bin_dir
  openshift_cluster   = length(regexall("^openshift", data.external.get_operator_config.result.packageName)) > 0
  cluster_type        = data.external.cluster_info.result.clusterType
  cluster_version     = data.external.cluster_info.result.clusterVersion
  console_host        = data.external.cluster_info.result.consoleHost
  operator_namespace  = local.openshift_cluster ? "openshift-operators" : "operators"
  webhook_name        = local.openshift_cluster ? "tekton-pipelines-webhook" : "tekton-operator-webhook"
  dashboard_namespace = local.cluster_type == "ocp4" ? "openshift-pipelines" : "tekton-pipelines"
  ingress_url         = local.cluster_type == "ocp4" ? "https://${local.console_host}/k8s/all-namespaces/tekton.dev~v1alpha1~Pipeline" : ""
  chart_name          = "tekton"
  chart_dir           = "${path.module}/chart/${local.chart_name}"
  created_by          = "tekton-${random_string.random.result}"
  pipeline_channel    = local.cluster_version == "4.8" ? "stable" : "latest"
  global_config       = {
    enabled = var.provision
    clusterType = local.cluster_type
    ingressSubdomain = var.cluster_ingress_hostname
    olmNamespace = data.external.get_operator_config.result.catalogSourceNamespace
    operatorNamespace = local.operator_namespace
  }
  tekton_operator_config  = {
    clusterType = local.cluster_type
    olmNamespace = data.external.get_operator_config.result.catalogSourceNamespace
    operatorNamespace = local.operator_namespace
    createdBy = local.created_by
    app = "tekton"
    ocpCatalog = {
      source  = data.external.get_operator_config.result.catalogSource
      name    = data.external.get_operator_config.result.packageName
      channel = data.external.get_operator_config.result.defaultChannel
    }
    operatorHub = {
      source  = data.external.get_operator_config.result.catalogSource
      name    = data.external.get_operator_config.result.packageName
      channel = data.external.get_operator_config.result.defaultChannel
    }
    webhookName = local.webhook_name
    tektonNamespace = local.dashboard_namespace
  }
  tool_config = {
    url = local.ingress_url
    name = "Tekton"
    applicationMenu = false
    enableConsoleLink = false
  }
}

data clis_check clis {
  clis = ["helm", "jq", "oc", "kubectl"]
}

data external get_operator_config {
  program = ["bash", "${path.module}/scripts/get-operator-config.sh"]

  query = {
    kube_config   = var.cluster_config_file_path
    olm_namespace = var.olm_namespace
    bin_dir       = local.bin_dir
  }
}

resource null_resource print_operator_config {
  provisioner "local-exec" {
    command = "echo '${jsonencode(data.external.get_operator_config.result)}'"
  }
}

resource "random_string" "random" {
  length           = 16
  lower            = true
  numeric          = true
  upper            = false
  special          = false
}

data external cluster_info {
  program = ["bash", "${path.module}/scripts/get-cluster-info.sh"]

  query = {
    bin_dir     = local.bin_dir
    kube_config = var.cluster_config_file_path
  }
}

resource null_resource print_cluster_info {
  provisioner "local-exec" {
    command = "echo '${jsonencode(data.external.cluster_info.result)}'"
  }
}

data external check_for_operator {
  program = ["bash", "${path.module}/scripts/check-for-operator.sh"]

  query = {
    bin_dir     = local.bin_dir
    kube_config = var.cluster_config_file_path
    namespace   = local.operator_namespace
    name        = data.external.get_operator_config.result.packageName
    created_by  = local.created_by
    crd         = "tektonconfig"
    title       = "Tekton"
  }
}

resource null_resource print_check_for_operator {
  provisioner "local-exec" {
    command = "echo '${jsonencode(data.external.check_for_operator.result)}'"
  }
}

resource null_resource tekton_operator_helm {

  triggers = {
    namespace = local.operator_namespace
    name = "tekton"
    chart = local.chart_dir
    values_file_content = nonsensitive(yamlencode({
      global = local.global_config
      tekton-operator = local.tekton_operator_config
      tool-config = local.tool_config
    }))
    kubeconfig = var.cluster_config_file_path
    tmp_dir    = local.tmp_dir
    bin_dir    = local.bin_dir
    created_by = local.created_by
    skip       = data.external.check_for_operator.result.exists
    subscription_name = data.external.get_operator_config.result.packageName
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

    command = "${path.module}/scripts/destroy-operator.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} ${self.triggers.subscription_name}"

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
        bin_dir = local.bin_dir
        cluster_version = local.cluster_version
        namespace = local.dashboard_namespace
        cluster_type = local.cluster_type
        kube_config = var.cluster_config_file_path
        skip = data.external.check_for_operator.result.exists
      })
    }
  }
}
