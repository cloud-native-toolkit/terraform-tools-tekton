#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
MODULE_DIR=$(cd ${SCRIPT_DIR}/..; pwd -P)

YAML_FILE=${MODULE_DIR}/tekton.yaml

echo "*** creating tekton openshift-pipelines-operator"
kubectl apply -f ${YAML_FILE}

count=0
echo "*** Waiting for Tekton CRDs to be available"
until kubectl get crd tasks.tekton.dev
do
    echo '>>> waiting for tekton CRD availability'
    sleep 30
done
echo '>>> Tekton CRDs are available'

count=0
echo "*** Waiting for Tekton CSV to be available"
until [[ $(oc get csv -o custom-columns=name:.metadata.name | grep openshift-pipelines-operator) =~ openshift-pipelines-operator ]]; do
  if [[ "$count" -eq 10 ]]; then
    echo '>>> Timed out waiting for Tekton CSV'
    exit 1
  fi

  echo '   >>> waiting for Tekton CSV availability'
  sleep 30
  count=$((count+1))
done

echo '>>> Tekton CSV is installed'
