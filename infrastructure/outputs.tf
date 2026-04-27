output "k3d_cluster_name" {
  value = terraform_data.k3d_cluster.output.k3d_cluster_name
}

output "kubeconfig_instruction" {
  value       = "To interact with the cluster, run: export KUBECONFIG=${local_file.kubeconfig.filename}"
  description = "Shell command to use the generated cluster credentials"
}
