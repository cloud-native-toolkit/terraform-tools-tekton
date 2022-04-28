module "dev_tools_namespace" {
  source = "github.com/ibm-garage-cloud/terraform-cluster-namespace.git"

  cluster_config_file_path = module.dev_cluster.config_file_path
  name                     = var.namespace
}

resource "local_file" "namespace" {
  filename = ".namespace"
  content = module.dev_tools_namespace.name
}
