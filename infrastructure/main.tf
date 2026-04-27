resource "terraform_data" "k3d_cluster" {
    # Triggers a full replacement if core infrastructure parameters change
    triggers_replace = {
        agent_count  = var.agent_count
        server_count = var.server_count
        k3s_version  = var.k3s_version
    }

    # Provisioning phase: Cluster creation + Cilium BPF Pre-requisites
    provisioner "local-exec" {
        command = <<EOT
            # Step 1: Create the cluster disabling default networking components
            # We disable ServiceLB (Klipper) to allow MetalLB later
            # We disable Flannel and NetworkPolicy to allow Cilium eBPF
            k3d cluster create ${var.k3d_cluster_name} \
                --agents ${var.agent_count} \
                --servers ${var.server_count} \
                --image rancher/k3s:${var.k3s_version} \
                --k3s-arg "--disable=servicelb@server:*" \
                --k3s-arg "--disable=traefik@server:*" \
                --k3s-arg "--flannel-backend=none@server:*" \
                --k3s-arg "--disable-network-policy@server:*" \
                --no-lb --wait
        EOT
    }

    provisioner "local-exec" {
        command = <<EOT
            # Step 2: Fix BPF Mounts for each node to enable Cilium eBPF mode
            # Without this, Cilium cannot manage the BPF filesystem on Docker nodes
                for node in $(docker ps --filter "name=k3d-${var.k3d_cluster_name}" --format "{{.Names}}"); do
                    echo "Fixing BPF and Cgroupv2 on $node..."
                    docker exec $node mount bpffs /sys/fs/bpf -t bpf || true
                    docker exec $node mount --make-shared /sys/fs/bpf || true
                    docker exec $node mkdir -p /run/cilium/cgroupv2
                    docker exec $node mount -t cgroup2 none /run/cilium/cgroupv2 || true
                    docker exec $node mount --make-shared /run/cilium/cgroupv2 || true
                done
        EOT
    }

    # Destruction phase: Clean up the cluster from the local machine
    provisioner "local-exec" {
        when    = destroy
        command = "k3d cluster delete ${self.output.k3d_cluster_name}"
    }

    # Export output for downstream resource consumption
    input = {
        k3d_cluster_name = var.k3d_cluster_name
    }
}

# Automatically generate and manage the kubeconfig file
resource "local_file" "kubeconfig" {
  depends_on = [terraform_data.k3d_cluster]
  filename   = "${path.module}/kubeconfig.yaml"
  content    = "" # Placeholder

  provisioner "local-exec" {
    command = "k3d kubeconfig get ${var.k3d_cluster_name} > ${self.filename}"
  }
}