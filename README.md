# Tekton terraform module

![Verify and release module](https://github.com/ibm-garage-cloud/terraform-tools-tekton/workflows/Verify%20and%20release%20module/badge.svg)

Module to install TektonCD in an OpenShift or Kubernetes cluster.

## Software dependencies

The module depends on the following software components:

- terraform v0.15

## Module dependencies

- Cluster
- OLM

## Example usage

See [example/](example) folder for full example usage

```hcl-terraform
module "tekton" {
  source = "github.com/ibm-garage-cloud/terraform-tools-tekton.git"

  cluster_config_file_path = module.cluster.config_file_path
  cluster_ingress_hostname = module.cluster.platform.ingress
  olm_namespace            = module.olm.olm_namespace
  operator_namespace       = module.olm.target_namespace
}
```
