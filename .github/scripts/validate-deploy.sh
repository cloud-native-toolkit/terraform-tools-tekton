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

NAMESPACE="openshift-operators"

check_k8s_resource "${NAMESPACE}" subscription openshift-pipelines-operator-rh
check_k8s_resource "${NAMESPACE}" csv "pipelines.*"
