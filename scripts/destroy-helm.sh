#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
CHART="$3"

if [[ "${PROVISION}" == "false" ]]; then
  echo "PROVISION is false. Skipping..."
  exit 0
fi

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR="./tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ -z "${BIN_DIR}" ]]; then
  BIN_DIR="/usr/local/bin"
fi

VALUES_FILE="${TMP_DIR}/${NAME}-values.yaml"

echo "${VALUES_FILE_CONTENT}" > "${VALUES_FILE}"

HELM=$(command -v helm || command -v ${BIN_DIR}/helm)
if [[ -z "${HELM}" ]]; then
  echo "Helm cli missing"
  exit 1
fi

if [[ -n "${REPO}" ]]; then
  repo_config="--repo ${REPO}"
fi

${HELM} template "${NAME}" "${CHART}" ${repo_config} -n "${NAMESPACE}" --values "${VALUES_FILE}" | \
  ${BIN_DIR}/kubectl delete -n "${NAMESPACE}" -f -
