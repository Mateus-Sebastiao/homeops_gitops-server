#!/bin/bash
# Fail immediately if a command fails, an unset variable is used, or a piped command fails.
set -euo pipefail

# Check for required argument: Cluster Name
readonly CLUSTER_NAME="${1:?Error: Cluster name not provided as first argument}"

# Single Source of Truth for images to be pre-loaded into the cluster
readonly TARGET_IMAGES=(
  "quay.io/cilium/operator-generic:v1.19.3"
  "quay.io/cilium/hubble-relay:v1.19.3"
  "quay.io/cilium/hubble-ui:v0.13.3"
  "quay.io/cilium/hubble-ui-backend:v0.13.3"
  "quay.io/cilium/cilium:v1.19.3"
  "quay.io/cilium/cilium-envoy:v1.36.6-1776000132-2437d2edeaf4d9b56ef279bd0d71127440c067aa"
)

# Encapsulated logic to import a single image into a specific node's containerd storage
import_to_node() {
  local image=$1
  local node=$2
  
  echo "  [→] Importing into node: $node"
  # Use 'ctr' with the 'k8s.io' namespace to ensure Kubernetes can see the image.
  # Redirecting stdout to /dev/null to keep Terraform logs clean.
  docker save "$image" | docker exec -i "$node" ctr -n k8s.io images import - >/dev/null
}

main() {
  echo "Fetching nodes for cluster: $CLUSTER_NAME..."
  
  # Dynamically discover all nodes belonging to the k3d cluster
  local nodes
  nodes=$(docker ps --filter "label=k3d.cluster=$CLUSTER_NAME" --format "{{.Names}}")

  if [[ -z "$nodes" ]]; then
    echo "Error: No nodes found for cluster '$CLUSTER_NAME'. Is the cluster running?"
    exit 1
  fi

  for img in "${TARGET_IMAGES[@]}"; do
    # Check if the image exists locally before attempting the save/pipe operation
    if docker image inspect "$img" >/dev/null 2>&1; then
      echo "Processing image: $img"
      for node in $nodes; do
        import_to_node "$img" "$node"
      done
    else
      echo "Warning: Image '$img' not found on host. Skipping..."
    fi
  done

  echo "Successfully pre-loaded images into $CLUSTER_NAME."
}

# Entry point execution
main
