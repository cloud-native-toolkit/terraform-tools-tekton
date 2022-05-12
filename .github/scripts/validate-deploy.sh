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

SKIP=$(cat .skip)
EXISTS=$(cat .exists)

echo "Module results: skip=${SKIP}, exists=${EXISTS}"

if [[ "${SKIP}" != "true" ]]; then
  check_k8s_resource "${NAMESPACE}" job tekton-webhook-test
else
  echo "Not checking for job since install was skipped"
fi

while kubectl get job/tekton-webhook-test -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  echo "Sleeping for 30 seconds to wait for the job to be deleted"
  sleep 30
done
