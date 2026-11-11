#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: Contributors to the Gardener project
#
# SPDX-License-Identifier: Apache-2.0

# Deploys the local cloud-controller-manager (CCM) into the self-hosted shoot (gind) cluster so that
# LoadBalancer-type Services (notably the istio ingress gateway) get their `.status.loadBalancer.ingress`
# assigned. Without this, the istio ManagedResource stays unhealthy (CheckService: "service is missing
# ingress status") and the shoot reconciliation blocks at "Waiting until Istio is ready".
#
# The standard `make cloud-provider-local-up` target cannot be used here: it relies on
# detect_kind_cluster_name, which requires a control-plane node whose providerID starts with `kind://`.
# gind (self-hosted shoot) nodes have no such providerID, so we invoke skaffold directly against the
# self-hosted-shoot kubeconfig and pass CLUSTER_NAME explicitly.

set -o nounset
set -o pipefail
set -o errexit

SHS_KUBECONFIG="${KUBECONFIG_SELFHOSTEDSHOOT_CLUSTER:-$(dirname "${0}")/../dev-setup/kubeconfigs/self-hosted-shoot/kubeconfig}"
CCM_NAMESPACE="kube-system"
CCM_DEPLOYMENT="cloud-controller-manager"

echo "> Deploying cloud-controller-manager into the self-hosted shoot cluster"
KUBECONFIG="$SHS_KUBECONFIG" \
SKAFFOLD_FILENAME="dev-setup/skaffold-cloud-provider-local.yaml" \
SKAFFOLD_DEFAULT_REPO="${SKAFFOLD_DEFAULT_REPO:-registry.local.gardener.cloud:5001}" \
SKAFFOLD_PUSH="${SKAFFOLD_PUSH:-true}" \
SKAFFOLD_LABEL="skaffold.dev/run-id=gardener-local" \
CLUSTER_NAME="gind" \
skaffold run

# The deployed chart does not render the networking-policy egress labels for the self-hosted scenario
# (see the `is-shoot` conditional in the cloud-controller-manager chart), and it has no scheduling
# constraints. On the self-hosted shoot the kube-system namespace enforces default-deny egress, and only
# the control-plane node reliably reaches the kube-apiserver. Pin the CCM to the control-plane node and
# add the egress-allow labels so it can talk to the apiserver and reconcile LoadBalancer Services.
echo "> Pinning CCM to the control-plane node and granting apiserver egress"
KUBECONFIG="$SHS_KUBECONFIG" kubectl patch deployment -n "$CCM_NAMESPACE" "$CCM_DEPLOYMENT" --type=merge -p '{
  "spec": {
    "template": {
      "metadata": {
        "labels": {
          "networking.gardener.cloud/to-apiserver": "allowed",
          "networking.gardener.cloud/to-runtime-apiserver": "allowed"
        }
      },
      "spec": {
        "nodeSelector": {"worker.gardener.cloud/pool": "control-plane"},
        "tolerations": [{"key": "node-role.kubernetes.io/control-plane", "operator": "Exists", "effect": "NoSchedule"}]
      }
    }
  }
}'

echo "> Waiting for CCM rollout"
KUBECONFIG="$SHS_KUBECONFIG" kubectl rollout status deployment -n "$CCM_NAMESPACE" "$CCM_DEPLOYMENT" --timeout=180s

echo "> cloud-controller-manager is ready; LoadBalancer Services will now get their ingress status"
