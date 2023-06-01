#!/usr/bin/env bash

set -e

INPUT=$(tee)

TMP_DIR=$(echo "${INPUT}" | grep "tmp_dir" | sed -E 's/.*"tmp_dir": ?"([^"]*)".*/\1/g')

mkdir -p "${TMP_DIR}" 1> /dev/null

echo "{\"tmp_dir\": \"${TMP_DIR}\"}"
