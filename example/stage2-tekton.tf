module "dev_tools_tekton" {
  source = "../"

  cluster_config_file_path = module.cluster.config_file_path
  cluster_ingress_hostname = module.cluster.platform.ingress
}

resource local_file skip {
  filename = "${path.cwd}/.skip"

  content = module.dev_tools_tekton.skip
}

resource local_file exists {
  filename = "${path.cwd}/.exists"

  content = module.dev_tools_tekton.exists
}

resource "null_resource" "output_values" {
  provisioner "local-exec" {
    command = "echo -n '${module.dev_tools_tekton.namespace}' > .namespace"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.dev_tools_tekton.subscription_name}' > .subscription_name"
  }
}
