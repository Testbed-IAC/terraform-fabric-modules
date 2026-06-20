output "kubeconfig" {
  description = "Cluster kubeconfig with the API server set to localhost. Use with the API tunnel."
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Local path of the written kubeconfig."
  value       = local.kubeconfig_path
}

output "control_plane_ip" {
  description = "Control-plane management IP."
  value       = local.cp_mgmt_ip
}

output "worker_ips" {
  description = "Worker management IPs by node name."
  value       = { for n in local.worker_nodes : n.name => fabric_slice.this.nodes[n.name].management_ip }
}

output "data_plane_ips" {
  description = "Data-plane IPs by node name."
  value       = local.data_ip
}

output "ssh_command" {
  description = "SSH to the control plane through the bastion."
  value       = "ssh ${local.ssh_flags} ${local.ssh_user}@${local.cp_mgmt_ip}"
}

output "api_tunnel_command" {
  description = "Forward the Kubernetes API to localhost:6443 so the kubeconfig works."
  value       = "ssh -L 6443:${local.server_data_ip}:6443 ${local.ssh_flags} ${local.ssh_user}@${local.cp_mgmt_ip}"
}

output "access_commands" {
  description = "Commands to reach cluster web UIs from localhost."
  value = merge(
    var.monitoring.enabled ? {
      grafana = local.grafana_lb ? "ssh -L 3000:${local.lb_grafana_ip}:80 ${local.ssh_flags} ${local.ssh_user}@${local.cp_mgmt_ip}  # http://localhost:3000" : "kubectl --kubeconfig ${local.kubeconfig_path} -n monitoring port-forward svc/monitoring-grafana 3000:80  # http://localhost:3000 (requires api_tunnel_command)"
    } : {},
    var.ingress ? {
      ingress = "ssh -L 8080:${local.lb_ingress_ip}:80 ${local.ssh_flags} ${local.ssh_user}@${local.cp_mgmt_ip}  # http://localhost:8080"
    } : {},
  )
}

output "grafana_password" {
  description = "Grafana admin password, if monitoring is enabled."
  value       = var.monitoring.enabled ? random_password.grafana.result : null
  sensitive   = true
}
