#!/usr/bin/env bash

oc get clusterversion -o json | jq -r '.items | .[] | .status.history | .[] | .version' | head -1 | sed -E "s/([0-9]+[.][0-9]+)[.][0-9]*/\1/g"
