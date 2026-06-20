locals {
  cidr_prefix = tonumber(split("/", var.data_cidr)[1])

  control_plane = {
    name      = "cp"
    role      = "control-plane"
    site      = coalesce(var.control_plane.site, var.site)
    cores     = var.control_plane.cores
    ram       = var.control_plane.ram
    disk      = var.control_plane.disk
    image_ref = var.control_plane.image_ref
    labels    = {}
    taints    = []
  }

  worker_nodes = flatten([
    for pool in var.workers : [
      for i in range(pool.count) : {
        name      = "${pool.name}-${i}"
        role      = "worker"
        site      = coalesce(pool.site, var.site)
        cores     = pool.cores
        ram       = pool.ram
        disk      = pool.disk
        image_ref = pool.image_ref
        labels    = pool.labels
        taints    = pool.taints
      }
    ]
  ])

  nodes        = concat([local.control_plane], local.worker_nodes)
  worker_names = [for n in local.worker_nodes : n.name]
  node_sites   = distinct([for n in local.nodes : n.site])

  data_ip = {
    for idx, n in local.nodes : n.name => cidrhost(var.data_cidr, 11 + idx)
  }
  server_data_ip = local.data_ip[local.control_plane.name]

  # Load-balancer pool sits above the node range in the data CIDR.
  lb_pool       = "${cidrhost(var.data_cidr, 200)}-${cidrhost(var.data_cidr, 250)}"
  lb_ingress_ip = cidrhost(var.data_cidr, 200)
  lb_grafana_ip = cidrhost(var.data_cidr, 201)

  bootstrap_token = "${random_string.token_id.result}.${random_string.token_secret.result}"

  ssh_user     = var.ssh.username
  node_key     = pathexpand(coalesce(var.ssh.private_key_path, "~/.ssh/id_rsa"))
  bastion_key  = pathexpand(coalesce(var.ssh.bastion_private_key, "~/work/fabric_config/fabric_bastion_key"))
  bastion_host = coalesce(var.ssh.bastion_host, data.fabric_bastion.this.host)
  bastion_user = coalesce(var.ssh.bastion_username, data.fabric_bastion.this.username)

  ssh_flags       = "-i ${local.node_key} -o ProxyCommand='ssh -i ${local.bastion_key} -W [%h]:%p ${local.bastion_user}@${local.bastion_host}'"
  kubeconfig_path = coalesce(var.kubeconfig_path, "${path.root}/${var.name}.kubeconfig")

  manifests_content = join("\n---\n", [for p in var.manifests : file(p)])

  helm_render = [
    for c in var.helm_charts : {
      name                = c.name
      namespace           = c.namespace
      version             = c.version
      repo                = c.repo
      chart               = c.chart
      is_local            = can(regex("^(\\./|\\.\\./|/)", c.chart))
      values_yaml         = yamlencode(c.values)
      values_file_content = c.values_file != null ? file(c.values_file) : ""
    }
  ]
  local_charts = [for c in local.helm_render : c if c.is_local]

  grafana_lb = var.lb == "metallb"

  workloads_hash = sha1(jsonencode({
    manifests = local.manifests_content
    charts    = local.helm_render
  }))

  supported_dashboards = ["kubernetes-cluster", "node-exporter", "kubernetes-pods"]
}
