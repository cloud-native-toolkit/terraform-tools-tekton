#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
CHART="$3"

HELM=$(command -v helm || command -v ./bin/helm)

if [[ -z "${HELM}" ]]; then
  curl -Lo helm.tar.gz https://get.helm.sh/helm-v3.6.1-linux-amd64.tar.gz
  tar xzf helm.tar.gz
  mkdir -p ./bin && mv ./linux-amd64/helm ./bin/helm
  rm -rf linux-amd64
  rm helm.tar.gz

  HELM="$(cd ./bin; pwd -P)/helm"
fi

${HELM} template "${NAME}" "${CHART}" | \
  kubectl apply --validate=false -n "${NAMESPACE}" -f -
