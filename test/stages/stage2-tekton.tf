module "dev_tools_tekton" {
  source = "./module"

  cluster_config_file_path = module.dev_cluster.config_file_path
  cluster_type             = module.dev_cluster.platform.type_code
  cluster_ingress_hostname = module.dev_cluster.platform.ingress
  tools_namespace          = module.dev_capture_state.namespace
}
