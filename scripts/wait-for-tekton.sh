#!/usr/bin/env bash

INPUT=$(tee)

export KUBECONFIG=$(echo "${INPUT}" | grep "kube_config" | sed -E 's/.*"kube_config": ?"([^"]*)".*/\1/g')
BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')
CLUSTER_TYPE=$(echo "${INPUT}" | grep "cluster_type" | sed -E 's/.*"cluster_type": ?"([^"]*)".*/\1/g')
VERSION=$(echo "${INPUT}" | grep "cluster_version" | sed -E 's/.*"cluster_version": ?"([^"]*)".*/\1/g')
NAMESPACE=$(echo "${INPUT}" | grep "namespace" | sed -E 's/.*"namespace": ?"([^"]*)".*/\1/g')
SKIP=$(echo "${INPUT}" | grep "skip" | sed -E 's/.*"skip": ?"([^"]*)".*/\1/g')

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl missing!" >&2
  exit 1
fi

if [[ "${CLUSTER_TYPE}" != "ocp4" ]]; then
  echo '{"message": "Cluster type is ocp4. Skipping..."}'
  exit 0
fi

count=0
until [[ $(kubectl get crd -o custom-columns=name:.metadata.name | grep -c "tekton.dev") -gt 0 ]]; do
  if [[ $count -eq 40 ]]; then
    echo "Timed out waiting for Tekton CRDs to be installed" >&2
    exit 1
  fi

  sleep 15
  count=$((count+1))
done

if [[ "${VERSION}" =~ 4[.]6 ]]; then
  echo '{"message": "Cluster is 4.6 version of Openshift. No need to wait for webhook."}'
  exit 0
fi

set -e

if [[ "${SKIP}" == "true" ]]; then
  echo '{"message": "Skipped tekton webhook check for existing install"}'
  exit 0
fi

count=0
until kubectl get job/tekton-webhook-test -n "${NAMESPACE}" 1> /dev/null 2> /dev/null || [[ "${count}" -eq 5 ]]; do
  count=$((count + 1))
  sleep 30
done

if [[ "${count}" -eq 5 ]]; then
  echo '{"message": "Timed out waiting for tekton-webhook-test to start", "status": "1"}'
  exit 0
fi

kubectl wait --for=condition=complete -n "${NAMESPACE}" --timeout=35m job/tekton-webhook-test 1> /dev/null

echo '{"message": "Tekton webhook created successfully", "status": "0"}'
