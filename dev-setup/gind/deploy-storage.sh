#!/usr/bin/env bash
# SPDX-FileCopyrightText: Contributors to the Gardener project
#
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o nounset
set -o pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
export KUBECONFIG="${KUBECONFIG:-$repo_root/dev-setup/kubeconfigs/self-hosted-shoot/kubeconfig}"
image_vector="$repo_root/pkg/provider-local/imagevector/images.yaml"
LOCAL_PATH_PROVISIONER_IMAGE="$(yq -er '.images[] | select(.name == "local-path-provisioner") | .repository + ":" + .tag' "$image_vector")"
LOCAL_PATH_HELPER_IMAGE="$(yq -er '.images[] | select(.name == "local-path-helper") | .repository + ":" + .tag' "$image_vector")"
export LOCAL_PATH_PROVISIONER_IMAGE LOCAL_PATH_HELPER_IMAGE
export SKAFFOLD_FILENAME="${SKAFFOLD_FILENAME:-$repo_root/dev-setup/skaffold-storage-local.yaml}"

echo "> Deploying local storage into the self-hosted shoot cluster"
skaffold run
kubectl rollout status deployment -n kube-system local-path-provisioner --timeout=180s
