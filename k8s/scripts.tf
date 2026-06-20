locals {
  prereq = {
    for n in local.nodes : n.name => templatefile("${path.module}/templates/prereq.sh.tftpl", {
      data_ip      = local.data_ip[n.name]
      cidr_prefix  = local.cidr_prefix
      service_cidr = var.svc_cidr
      k8s_version  = var.k8s_version
      storage      = var.storage
    })
  }

  server_script = templatefile("${path.module}/templates/control-plane.sh.tftpl", {
    prereq       = local.prereq[local.control_plane.name]
    server_ip    = local.server_data_ip
    pod_cidr     = var.pod_cidr
    service_cidr = var.svc_cidr
    token        = local.bootstrap_token
    node_name    = local.control_plane.name
  })

  worker_scripts = {
    for n in local.worker_nodes : n.name => templatefile("${path.module}/templates/worker.sh.tftpl", {
      prereq    = local.prereq[n.name]
      server_ip = local.server_data_ip
      token     = local.bootstrap_token
      node_name = n.name
    })
  }

  addons_script = templatefile("${path.module}/templates/addons.sh.tftpl", {
    node_count            = length(local.nodes)
    worker_nodes          = [for n in local.worker_nodes : { name = n.name, labels = n.labels, taints = n.taints }]
    storage               = var.storage
    lb                    = var.lb
    ingress               = var.ingress
    monitoring_enabled    = var.monitoring.enabled
    monitoring_kubernetes = var.monitoring.kubernetes
    monitoring_nodes      = var.monitoring.nodes
    lb_pool               = local.lb_pool
    lb_ingress_ip         = local.lb_ingress_ip
    lb_grafana_ip         = local.lb_grafana_ip
    grafana_lb            = local.grafana_lb
    helm_timeout          = var.timeouts.helm
  })

  deploy_script = templatefile("${path.module}/templates/deploy.sh.tftpl", {
    manifests_present = length(var.manifests) > 0
    helm_charts       = local.helm_render
    helm_timeout      = var.timeouts.helm
  })
}
