resource "null_resource" "control_plane" {
  triggers = {
    slice  = fabric_slice.this.id
    script = sha1(local.server_script)
  }

  connection {
    type                = "ssh"
    host                = fabric_slice.this.nodes[local.control_plane.name].management_ip
    user                = local.ssh_user
    private_key         = file(local.node_key)
    bastion_host        = local.bastion_host
    bastion_user        = local.bastion_user
    bastion_private_key = file(local.bastion_key)
    timeout             = var.timeouts.node
  }

  provisioner "remote-exec" {
    inline = [local.server_script]
  }
}

resource "null_resource" "workers" {
  for_each   = toset(local.worker_names)
  depends_on = [null_resource.control_plane]

  triggers = {
    slice  = fabric_slice.this.id
    script = sha1(local.worker_scripts[each.key])
  }

  connection {
    type                = "ssh"
    host                = fabric_slice.this.nodes[each.key].management_ip
    user                = local.ssh_user
    private_key         = file(local.node_key)
    bastion_host        = local.bastion_host
    bastion_user        = local.bastion_user
    bastion_private_key = file(local.bastion_key)
    timeout             = var.timeouts.node
  }

  provisioner "remote-exec" {
    inline = [local.worker_scripts[each.key]]
  }
}

resource "null_resource" "addons" {
  depends_on = [null_resource.workers]

  triggers = {
    slice  = fabric_slice.this.id
    script = sha1(local.addons_script)
  }

  connection {
    type                = "ssh"
    host                = fabric_slice.this.nodes[local.control_plane.name].management_ip
    user                = local.ssh_user
    private_key         = file(local.node_key)
    bastion_host        = local.bastion_host
    bastion_user        = local.bastion_user
    bastion_private_key = file(local.bastion_key)
    timeout             = var.timeouts.node
  }

  provisioner "file" {
    content     = random_password.grafana.result
    destination = "/tmp/grafana-pw"
  }

  provisioner "remote-exec" {
    inline = [local.addons_script]
  }
}

resource "null_resource" "local_charts" {
  for_each   = { for c in local.local_charts : c.name => c }
  depends_on = [null_resource.control_plane]

  triggers = {
    slice = fabric_slice.this.id
    chart = each.key
  }

  connection {
    type                = "ssh"
    host                = fabric_slice.this.nodes[local.control_plane.name].management_ip
    user                = local.ssh_user
    private_key         = file(local.node_key)
    bastion_host        = local.bastion_host
    bastion_user        = local.bastion_user
    bastion_private_key = file(local.bastion_key)
    timeout             = var.timeouts.node
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /tmp/charts/${each.key}"]
  }

  provisioner "file" {
    source      = "${each.value.chart}/"
    destination = "/tmp/charts/${each.key}"
  }
}

resource "null_resource" "deploy" {
  depends_on = [null_resource.addons, null_resource.local_charts]

  triggers = {
    slice     = fabric_slice.this.id
    workloads = local.workloads_hash
  }

  connection {
    type                = "ssh"
    host                = fabric_slice.this.nodes[local.control_plane.name].management_ip
    user                = local.ssh_user
    private_key         = file(local.node_key)
    bastion_host        = local.bastion_host
    bastion_user        = local.bastion_user
    bastion_private_key = file(local.bastion_key)
    timeout             = var.timeouts.node
  }

  provisioner "file" {
    content     = local.manifests_content
    destination = "/tmp/k8s-manifests.yaml"
  }

  provisioner "remote-exec" {
    inline = [local.deploy_script]
  }
}
