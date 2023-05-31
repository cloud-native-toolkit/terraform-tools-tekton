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
SUBSCRIPTION_NAME=$(cat .subscription_name)

check_k8s_resource "${NAMESPACE}" subscription "${SUBSCRIPTION_NAME}"
CURRENT_CSV=$(kubectl get subscription -n "${NAMESPACE}" "${SUBSCRIPTION_NAME}" -o json | jq -r '.status.currentCSV // empty')

if [[ -z "${CURRENT_CSV}" ]]; then
  echo "Current csv not found" >&2
  exit 1
fi

check_k8s_resource "${NAMESPACE}" csv "${CURRENT_CSV}"

SKIP=$(cat .skip)
EXISTS=$(cat .exists)

if [[ $(oc get tektonconfig -o json | jq '.items | length') -eq 0 ]]; then
  echo "Tekton config not found" >&2
  exit 1
fi
kubectl get tektonconfig -o yaml

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
