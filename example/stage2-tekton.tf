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

