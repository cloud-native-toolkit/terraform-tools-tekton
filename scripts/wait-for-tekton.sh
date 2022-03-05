#!/usr/bin/env bash

INPUT=$(tee)

export KUBECONFIG=$(echo "${INPUT}" | grep "kube_config" | sed -E 's/.*"kube_config": ?"([^"]*)".*/\1/g')
BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')
CLUSTER_TYPE=$(echo "${INPUT}" | grep "cluster_type" | sed -E 's/.*"cluster_type": ?"([^"]*)".*/\1/g')
VERSION=$(echo "${INPUT}" | grep "cluster_version" | sed -E 's/.*"cluster_version": ?"([^"]*)".*/\1/g')
TEKTON_NAMESPACE=$(echo "${INPUT}" | grep "tekton_namespace" | sed -E 's/.*"tekton_namespace": ?"([^"]*)".*/\1/g')
NAMESPACE=$(echo "${INPUT}" | grep "tools_namespace" | sed -E 's/.*"tools_namespace": ?"([^"]*)".*/\1/g')

if [[ -z "${BIN_DIR}" ]]; then
  BIN_DIR="/usr/local/bin"
fi

if ! command -v ${BIN_DIR}/kubectl; then
  echo "kubectl missing!" >&2
  exit 1
fi

if [[ "${CLUSTER_TYPE}" != "ocp4" ]]; then
  echo '{"message": "Cluster type is ocp4. Skipping..."}'
  exit 0
fi

count=0
until [[ $(${BIN_DIR}/kubectl get crd -o custom-columns=name:.metadata.name | grep -c "tekton.dev") -gt 0 ]]; do
  if [[ $count -eq 20 ]]; then
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

URL="http://tekton-pipelines-webhook.${TEKTON_NAMESPACE}.svc:8080"

cat <<EOF | ${BIN_DIR}/kubectl apply -n "${NAMESPACE}" -f - 1> /dev/null
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tekton-webhook-test
---
apiVersion: batch/v1
kind: Job
metadata:
  name: tekton-webhook-test
spec:
    template:
        spec:
            serviceAccountName: tekton-webhook-test
            initContainers:
              - name: wait-for-tekton-webhook
                image: quay.io/ibmgaragecloud/alpine-curl
                imagePullPolicy: IfNotPresent
                command: ["sh"]
                args:
                  - "-c"
                  - "count=0; until curl -Iskf ${URL} || [[ \$count -eq 20 ]]; do echo \">>> waiting for ${URL}\"; sleep 90; count=\$((count + 1)); done; if [[ \$count -eq 20 ]]; then echo \"Timeout\"; exit 1; else echo \">>> Started\"; fi"
            containers:
                - name: tekton-webhook-started
                  image: quay.io/ibmgaragecloud/alpine-curl
                  imagePullPolicy: Always
                  command: ["sh"]
                  args:
                    - "-c"
                    - "curl -Iskf ${URL}"
            restartPolicy: Never
    backoffLimit: 1
EOF

${BIN_DIR}/kubectl wait --for=condition=complete --timeout=35m job/tekton-webhook-test 1> /dev/null

echo '{"message": "Tekton webhook created successfully"}'
