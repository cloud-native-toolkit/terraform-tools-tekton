#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

NAMESPACE="$1"
NAME="$2"
CHART="$3"

if [[ "${SKIP}" == "true" ]]; then
  echo "Skipping helm deploy: ${NAME} ${CHART}"
  exit 0
fi

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

SUBSCRIPTION_NAME="openshift-pipelines-operator-rh"
SUBSCRIPTION=$(oc get subscription -n "${NAMESPACE}" -o json | jq --arg NAME "${SUBSCRIPTION_NAME}" -r '.items[] | select(.spec.name == $NAME) | .metadata.name // empty')
CSV_NAME=$(oc get subscription -n "${NAMESPACE}" "${SUBSCRIPTION}" -o json | jq -r '.status.currentCSV // empty')

echo "Uninstalling operator helm chart"
"${SCRIPT_DIR}/destroy-helm.sh" "${NAMESPACE}" "${NAME}" "${CHART}"

SUBSCRIPTION2=$(oc get subscription -n "${NAMESPACE}" -o json | jq --arg NAME "${SUBSCRIPTION_NAME}" -r '.items[] | select(.spec.name == $NAME) | .metadata.name // empty')

if ! oc get subscription -n "${NAMESPACE}" "${SUBSCRIPTION}" && [[ -n "${CSV_NAME}" ]]; then
  echo "Deleting CSV in ${NAMESPACE}"

  oc delete csv "${CSV_NAME}" -n "${NAMESPACE}"

  echo "CSVs deleted from ${NAMESPACE}"
else
  echo "Subscription still installed with csv ${CSV_NAME}"
  oc get subscription -A
fi
