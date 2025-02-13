#!/usr/bin/env bash

SCRIPT_PATH="$(readlink -f "${0}")"
SCRIPT_DIR="$(dirname ${SCRIPT_PATH})"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
PROJECT_NAME="$(basename "${PROJECT_ROOT}")"

#echo $PROJECT_ROOT
#echo $PROJECT_NAME
#
#exit

cd "${PROJECT_ROOT}"/.. || exit 1
tar -c "${PROJECT_NAME}" | ssh ${1} 'tar -x'
