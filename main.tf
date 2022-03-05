
locals {
  tmp_dir             = data.external.setup_dirs.result.tmp_dir
  cluster_type        = data.external.cluster_info.result.clusterType
  cluster_version     = data.external.cluster_info.result.clusterVersion
  console_host        = data.external.cluster_info.result.consoleHost
  dashboard_namespace = local.cluster_type == "ocp4" ? "openshift-pipelines" : "tekton-pipelines"
  ingress_url         = local.cluster_type == "ocp4" ? "https://${local.console_host}/k8s/all-namespaces/tekton.dev~v1alpha1~Pipeline" : ""
  gitops_dir          = var.gitops_dir != "" ? var.gitops_dir : "${path.cwd}/gitops"
  chart_name          = "tekton"
  chart_dir           = "${local.gitops_dir}/${local.chart_name}"
  global_config       = {
    enabled = var.provision
    clusterType = local.cluster_type
    ingressSubdomain = var.cluster_ingress_hostname
  }
  tekton_operator_config  = {
    clusterType = local.cluster_type
    olmNamespace = var.olm_namespace
    operatorNamespace = var.operator_namespace
    app = "tekton"
    ocpCatalog = {
      channel = "stable"
    }
  }
  tool_config = {
    url = local.ingress_url
    applicationMenu = false
  }
}

module setup_clis {
  source = "github.com/cloud-native-toolkit/terraform-util-clis.git"

  clis = ["jq", "oc", "kubectl", "helm"]
}

data external setup_dirs {
  program = ["bash", "${path.module}/scripts/setup-dirs.sh"]

  query = {
    tmp_dir = "${path.cwd}/.tmp/tekton"
  }
}

data external cluster_info {
  program = ["bash", "${path.module}/scripts/get-cluster-info.sh"]

  query = {
    bin_dir     = module.setup_clis.bin_dir
    kube_config = var.cluster_config_file_path
  }
}

resource "null_resource" "setup-chart" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.chart_dir} && cp -R ${path.module}/chart/${local.chart_name}/* ${local.chart_dir}"
  }
}

resource "local_file" "tekton-values" {
  depends_on = [null_resource.setup-chart]

  content  = yamlencode({
    global = local.global_config
    tekton-operator = local.tekton_operator_config
    tool-config = local.tool_config
  })
  filename = "${local.chart_dir}/values.yaml"
}

resource null_resource helm_tekton {
  depends_on = [local_file.tekton-values]
  count = var.mode != "setup" ? 1 : 0

  triggers = {
    bin_dir = module.setup_clis.bin_dir
    namespace = var.tools_namespace
    name = "tekton"
    chart = local.chart_dir
    kubeconfig = var.cluster_config_file_path
    provision = var.provision && local.cluster_type == "ocp4"
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh '${self.triggers.namespace}' '${self.triggers.name}' '${self.triggers.chart}'"

    environment = {
      BIN_DIR = self.triggers.bin_dir
      KUBECONFIG = self.triggers.kubeconfig
      PROVISION = self.triggers.provision
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh '${self.triggers.namespace}' '${self.triggers.name}' '${self.triggers.chart}'"

    environment = {
      BIN_DIR = self.triggers.bin_dir
      KUBECONFIG = self.triggers.kubeconfig
      PROVISION = self.triggers.provision
    }
  }
}

data external tekton_ready {
  depends_on = [null_resource.helm_tekton]
  count = var.mode != "setup" ? 1 : 0

  program = ["bash", "${path.module}/scripts/wait-for-crds.sh"]

  query = {
    bin_dir = module.setup_clis.bin_dir
    cluster_version = local.cluster_version
    tekton_namespace = local.dashboard_namespace
    tools_namespace = var.tools_namespace
    cluster_type = local.cluster_type
    kube_config = var.cluster_config_file_path
  }
}

resource "null_resource" "delete-pipeline-sa" {
  depends_on = [null_resource.helm_tekton]

  triggers = {
    NAMESPACE  = var.tools_namespace
    KUBECONFIG = var.cluster_config_file_path
  }

  provisioner "local-exec" {
    when = destroy

    command = "${module.setup_clis.bin_dir}/kubectl delete serviceaccount -n ${self.triggers.NAMESPACE} pipeline || exit 0"

    environment = {
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }
}
