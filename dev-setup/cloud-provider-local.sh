#!/usr/bin/env bash
# SPDX-FileCopyrightText: Contributors to the Gardener project
#
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail

source "$(dirname "$0")/scenario.sh"

case "${SCENARIO:-kind}" in
  kind)
    if [[ -z "${CLUSTER_NAME:-}" ]]; then
      detect_kind_cluster_name
    fi
    ;;
  unmanaged-infra)
    export KUBECONFIG="${KUBECONFIG:-$KUBECONFIG_SELFHOSTEDSHOOT_CLUSTER}"
    export CLUSTER_NAME="${CLUSTER_NAME:-gind}"
    export SKAFFOLD_PROFILE="unmanaged-infra"
    ;;
  *)
    echo "Error: Invalid scenario '${SCENARIO}'. Valid options are: kind unmanaged-infra." >&2
    exit 1
    ;;
esac

COMMAND="${1:-up}"
VALID_COMMANDS=("up" "dev" "debug" "down")

case "$COMMAND" in
  up)
    skaffold run
    if [[ "${SCENARIO:-kind}" == "unmanaged-infra" ]]; then
      kubectl rollout status deployment -n kube-system cloud-controller-manager --timeout=180s
    fi
   ;;

  dev)
    skaffold dev
   ;;

  debug)
    skaffold debug
   ;;

  down)
    skaffold delete
    ;;

  *)
    echo "Error: Invalid command '${COMMAND}'. Valid options are: ${VALID_COMMANDS[*]}." >&2
    exit 1
   ;;
esac
