#!/bin/bash
CLUSTER_NAME=$1

# List of target images
IMAGES=(
  "quay.io/cilium/operator-generic:v1.19.3"
  "quay.io/cilium/hubble-relay:v1.19.3"
  "quay.io/cilium/hubble-ui:v0.13.3"
  "quay.io/cilium/hubble-ui-backend:v0.13.3"
  "quay.io/cilium/cilium:v1.19.3"
  "quay.io/cilium/cilium-envoy:v1.36.6-1776000132-2437d2edeaf4d9b56ef279bd0d71127440c067aa"
  "ollama/ollama:0.21.3-rc0"
)

for img in "${IMAGES[@]}"; do
  # Idempotent check: Does the image exist on the local machine?
  if docker image inspect "$img" >/dev/null 2>&1; then
    echo "Importing $img to k3d..."
    # k3d image import is inherently idempotent (it won't duplicate data)
    k3d image import "$img" -c "$CLUSTER_NAME"
  else
    echo "$img not found on host. Falling back to internet download."
  fi
done
