terraform {
  required_version = ">= 1.4.0" # Required for terraform_data support

  required_providers {
    # Local provider manages the kubeconfig file generation
    local = {
      source  = "hashicorp/local"
      version = "~> 2.8.0"
    }
  }
}