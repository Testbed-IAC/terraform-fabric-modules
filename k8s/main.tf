data "fabric_bastion" "this" {}

resource "random_string" "token_id" {
  length  = 6
  upper   = false
  special = false
}

resource "random_string" "token_secret" {
  length  = 16
  upper   = false
  special = false
}

resource "random_password" "grafana" {
  length  = 20
  special = false
}

resource "fabric_slice" "this" {
  name     = var.name
  ssh_keys = [var.ssh_key]

  dynamic "node" {
    for_each = { for n in local.nodes : n.name => n }
    content {
      name      = node.value.name
      site      = node.value.site
      image_ref = node.value.image_ref
      cores     = node.value.cores
      ram       = node.value.ram
      disk      = node.value.disk

      component {
        name  = "nic0"
        type  = "SharedNIC"
        model = "ConnectX-6"
      }
    }
  }

  network {
    name = "cluster-net"
    type = "L2Bridge"

    dynamic "interface" {
      for_each = { for n in local.nodes : n.name => n }
      content {
        node      = interface.value.name
        component = "nic0"
      }
    }
  }

  timeouts {
    create = var.timeouts.slice
    delete = var.timeouts.slice
  }

  lifecycle {
    precondition {
      condition     = length(local.node_sites) == 1 && local.node_sites[0] == var.site
      error_message = "All nodes must be at the same site. control_plane.site and worker pool sites must equal var.site."
    }
    precondition {
      condition     = !var.ingress || var.lb == "metallb"
      error_message = "ingress = true requires lb = \"metallb\"."
    }
    precondition {
      condition     = length(setsubtract(var.monitoring.dashboards, local.supported_dashboards)) == 0
      error_message = "monitoring.dashboards may only contain: ${join(", ", local.supported_dashboards)}."
    }
  }
}
