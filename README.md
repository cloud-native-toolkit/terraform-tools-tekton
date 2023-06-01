# Tekton terraform module

![Verify and release module](https://github.com/ibm-garage-cloud/terraform-tools-tekton/workflows/Verify%20and%20release%20module/badge.svg)

Module to install TektonCD in an OpenShift or Kubernetes cluster.

**Note:** At the moment, because of a lag in the version of the Tekton operator available in the OperatorHub catalog, 
this module (and the OperatorHub Tekton operator) only supports Kubernetes version < 1.25. This
[issue](https://github.com/k8s-operatorhub/community-operators/issues/2837) tracks the fix. Once addressed, this module
will automatically support Kubernetes versions >= 1.25 without update.

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
