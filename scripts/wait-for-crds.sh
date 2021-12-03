#!/usr/bin/env bash

count=0
until [[ $(kubectl get crd -o custom-columns=name:.metadata.name | grep -c "tekton.dev") -gt 0 ]]; do
  if [[ $count -eq 200 ]]; then
    echo "Timed out waiting for Tekton CRDs to be installed"
    exit 1
  fi

  echo "Waiting for Tekton CRDs to be installed"
  sleep 15
  count=$((count+1))
done
