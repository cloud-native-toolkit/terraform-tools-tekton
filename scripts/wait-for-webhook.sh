#!/usr/bin/env bash

NAMESPACE="$1"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR=".tmp"
fi
mkdir -p "${TMP_DIR}"

FILENAME="${TMP_DIR}/tekton-webhook-test.yaml"
URL="http://tekton-pipelines-webhook.openshift-pipelines.svc:8080"

cat > "${FILENAME}" << EOL
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
EOL

kubectl apply -n "${NAMESPACE}" -f "${FILENAME}"

echo "Waiting for webhook..."
kubectl wait --for=condition=complete --timeout=35m job/tekton-webhook-test
