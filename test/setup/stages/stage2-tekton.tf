module "dev_tools_tekton" {
  source = "./modules"

  cluster_type             = module.dev_cluster.type_code
  cluster_config_file_path = module.dev_cluster.config_file_path
  cluster_ingress_hostname = module.dev_cluster.ingress_hostname
  tools_namespace          = module.dev_capture_state.namespace
}
