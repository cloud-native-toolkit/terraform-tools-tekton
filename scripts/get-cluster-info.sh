#!/usr/bin/env bash

INPUT=$(tee)

export KUBECONFIG=$(echo "${INPUT}" | grep "kube_config" | sed -E 's/.*"kube_config": ?"([^"]*)".*/\1/g')
BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')

if [[ -z "${BIN_DIR}" ]]; then
  BIN_DIR="/usr/local/bin"
fi

if ! command -v ${BIN_DIR}/oc; then
  echo "OpenShift cli missing!" >&2
  exit 1
fi

CLUSTER_TYPE="kubernetes"
if ${BIN_DIR}/oc explain route 1> /dev/null 2> /dev/null; then
  CLUSTER_TYPE="ocp4"
fi

if ! ${BIN_DIR}/kubectl get clusterversion 1> /dev/null 2> /dev/null; then
  CLUSTER_VERSION=$(${BIN_DIR}/kubectl version | grep -i server | sed -E "s/.*: +[vV]*(.*)/\1/g")
else
  CLUSTER_VERSION=$(${BIN_DIR}/oc get clusterversion | grep -E "^version" | sed -E "s/version[ \t]+([0-9.]+).*/\1/g")
fi

CONSOLE_HOST=""
if [[ "${CLUSTER_TYPE}" == "ocp4" ]]; then
  CONSOLE_HOST=$(${BIN_DIR}/oc whoami --show-console | sed -E 's/.*https?://(.*)/\1/g')
fi

echo '{}' | ${BIN_DIR}/jq \
  --arg CLUSTER_VERSION "${CLUSTER_VERSION}" \
  --arg CLUSTER_TYPE "${CLUSTER_TYPE}" \
  --arg CONSOLE_HOST "${CONSOLE_HOST}" \
  '{"clusterVersion": $CLUSTER_VERSION, "clusterType": $CLUSTER_TYPE, "consoleHost": $CONSOLE_HOST}'
