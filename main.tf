
locals {
  tmp_dir             = "${path.cwd}/.tmp"
  dashboard_namespace = var.cluster_type == "ocp4" ? "openshift-pipelines" : "tekton-pipelines"
  dashboard_file      = var.cluster_type == "ocp4" ? var.tekton_dashboard_yaml_file_ocp : var.tekton_dashboard_yaml_file_k8s
  ingress_url         = var.cluster_type == "ocp4" ? "https://${data.local_file.console-host[0].content}/k8s/all-namespaces/tekton.dev~v1alpha1~Pipeline" : ""
  console_host_file   = "${local.tmp_dir}/console.host"
  gitops_dir          = var.gitops_dir != "" ? var.gitops_dir : "${path.cwd}/gitops"
  chart_name          = "tekton"
  chart_dir           = "${local.gitops_dir}/${local.chart_name}"
  cluster_version_file = "${local.tmp_dir}/cluster.version"
  global_config       = {
    enabled = var.provision
    clusterType = var.cluster_type
    ingressSubdomain = var.cluster_ingress_hostname
  }
  tekton_operator_config  = {
    clusterType = var.cluster_type
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

resource "null_resource" "setup_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.tmp_dir}"
  }

  provisioner "local-exec" {
    command = "echo 'Provision tekton: ${var.provision}'"
  }
}

resource "null_resource" "cluster_version" {
  depends_on = [null_resource.setup_dirs]

  provisioner "local-exec" {
    command = "${path.module}/scripts/determine-cluster-version.sh > ${local.cluster_version_file}"

    environment = {
      KUBECONFIG = var.cluster_config_file_path
    }
  }
}

data "local_file" "cluster_version" {
  depends_on = [null_resource.cluster_version]

  filename = local.cluster_version_file
}

resource "null_resource" "setup-chart" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.chart_dir} && cp -R ${path.module}/chart/${local.chart_name}/* ${local.chart_dir}"
  }
}

resource "null_resource" "read-console-host" {
  count = var.cluster_type == "ocp4" ? 1 : 0
  depends_on = [null_resource.setup_dirs]

  provisioner "local-exec" {
    command = "kubectl get -n openshift-console route/console -o jsonpath='{.spec.host}' > ${local.console_host_file}"

    environment = {
      KUBECONFIG = var.cluster_config_file_path
    }
  }
}

data "local_file" "console-host" {
  count = var.cluster_type == "ocp4" ? 1 : 0
  depends_on = [null_resource.read-console-host]

  filename = local.console_host_file
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

resource "null_resource" "print-values" {
  provisioner "local-exec" {
    command = "cat ${local_file.tekton-values.filename}"
  }
}

resource null_resource helm_tekton {
  depends_on = [local_file.tekton-values]
  count = var.mode != "setup" && var.cluster_type == "ocp4" ? 1 : 0

  triggers = {
    namespace = var.tools_namespace
    name = "tekton"
    chart = local.chart_dir
    kubeconfig = var.cluster_config_file_path
    provision = var.provision
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh '${self.triggers.namespace}' '${self.triggers.name}' '${self.triggers.chart}'"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      PROVISION = self.triggers.provision
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh '${self.triggers.namespace}' '${self.triggers.name}' '${self.triggers.chart}'"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      PROVISION = self.triggers.provision
    }
  }
}

resource "null_resource" "wait-for-crd" {
  depends_on = [null_resource.helm_tekton]
  count = var.mode != "setup" && var.cluster_type == "ocp4" ? 1 : 0

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-crds.sh"

    environment = {
      KUBECONFIG = var.cluster_config_file_path
    }
  }
}

resource "null_resource" "wait-for-webhook" {
  depends_on = [null_resource.wait-for-crd]
  count = var.mode != "setup" && var.cluster_type == "ocp4" ? 1 : 0

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-webhook.sh '${var.tools_namespace}'"

    environment = {
      KUBECONFIG = var.cluster_config_file_path
    }
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

    command = "kubectl delete serviceaccount -n ${self.triggers.NAMESPACE} pipeline || exit 0"

    environment = {
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }
}
