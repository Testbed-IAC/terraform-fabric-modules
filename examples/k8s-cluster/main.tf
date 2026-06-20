terraform {
  required_version = ">= 1.3.0"

  required_providers {
    fabric = {
      source  = "Testbed-IAC/fabric"
      version = ">= 0.1.1"
    }
  }
}

provider "fabric" {}

module "k8s" {
  source = "../../k8s"

  name    = "demo"
  site    = var.site
  ssh_key = file(pathexpand(var.ssh_public_key))

  workers = [
    { name = "worker", count = 2, ram = 8 },
  ]

  storage = "longhorn"
  lb      = "metallb"
  ingress = true
  monitoring = {
    enabled = true
  }

  manifests = ["${path.module}/manifests/nginx.yaml"]

  helm_charts = [
    {
      name      = "podinfo"
      repo      = "https://stefanprodan.github.io/podinfo"
      chart     = "podinfo"
      version   = "6.14.0"
      namespace = "demo"
      values    = { replicaCount = 1 }
    },
  ]

  ssh = {
    private_key_path    = var.ssh_private_key
    bastion_private_key = var.bastion_private_key
  }
}

output "ssh_command" { value = module.k8s.ssh_command }
output "api_tunnel" { value = module.k8s.api_tunnel_command }
output "access_commands" { value = module.k8s.access_commands }
output "kubeconfig_path" { value = module.k8s.kubeconfig_path }

output "grafana_password" {
  value     = module.k8s.grafana_password
  sensitive = true
}
