#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

BIN_DIR=$(cat .bin_dir)

if [[ -f .kubeconfig ]]; then
  KUBECONFIG=$(cat .kubeconfig)
else
  KUBECONFIG="${PWD}/.kube/config"
fi
export KUBECONFIG

source "${SCRIPT_DIR}/validation-functions.sh"

NAMESPACE=$(cat .namespace)

check_k8s_resource openshift-operators subscription openshift-pipelines-operator-rh
check_k8s_resource openshift-operators csv "redhat-openshift-pipelines.*"
