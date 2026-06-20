# Fetch admin.conf from the control plane and rewrite the API endpoint to
# localhost; it is reachable after opening the API tunnel (see outputs).
locals {
  cp_mgmt_ip = fabric_slice.this.nodes[local.control_plane.name].management_ip

  ssh_opts         = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ConnectTimeout=20"
  kubeconfig_fetch = <<-CMD
    set -e
    SSH=ssh
    [ -x /c/Windows/System32/OpenSSH/ssh.exe ] && SSH=/c/Windows/System32/OpenSSH/ssh.exe
    mkdir -p "$(dirname '${local.kubeconfig_path}')"
    "$SSH" ${local.ssh_opts} -i '${local.node_key}' \
      -o ProxyCommand='ssh ${local.ssh_opts} -i ${local.bastion_key} -W [%h]:%p ${local.bastion_user}@${local.bastion_host}' \
      ${local.ssh_user}@${local.cp_mgmt_ip} 'sudo cat /etc/kubernetes/admin.conf' \
      | sed 's#server: https://[^ ]*#server: https://127.0.0.1:6443#' > '${local.kubeconfig_path}'
    test -s '${local.kubeconfig_path}'
  CMD
}

resource "null_resource" "kubeconfig" {
  depends_on = [null_resource.deploy]

  triggers = {
    deploy = null_resource.deploy.id
    path   = local.kubeconfig_path
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = local.kubeconfig_fetch
  }
}

data "local_file" "kubeconfig" {
  depends_on = [null_resource.kubeconfig]
  filename   = local.kubeconfig_path
}
