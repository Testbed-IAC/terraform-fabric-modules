variable "name" {
  description = "Slice and cluster name."
  type        = string
}

variable "site" {
  description = "Default FABRIC site for all nodes. Overridable per control_plane and worker pool, but all nodes must resolve to the same site."
  type        = string
}

variable "ssh_key" {
  description = "Public SSH key installed on every node."
  type        = string
}

variable "control_plane" {
  description = "Control-plane node sizing and placement."
  type = object({
    site      = optional(string)
    cores     = optional(number, 2)
    ram       = optional(number, 8)
    disk      = optional(number, 50)
    image_ref = optional(string, "default_ubuntu_22")
  })
  default = {}
}

variable "workers" {
  description = "Worker pools. Each pool produces `count` nodes named <pool>-<index>."
  type = list(object({
    name      = string
    count     = optional(number, 1)
    site      = optional(string)
    cores     = optional(number, 2)
    ram       = optional(number, 4)
    disk      = optional(number, 20)
    image_ref = optional(string, "default_ubuntu_22")
    labels    = optional(map(string), {})
    taints    = optional(list(string), [])
  }))
  default = [{ name = "worker" }]

  validation {
    condition     = length(var.workers) == length(distinct([for p in var.workers : p.name]))
    error_message = "Worker pool names must be unique."
  }
  validation {
    condition     = alltrue([for p in var.workers : p.count >= 1])
    error_message = "Each worker pool count must be at least 1."
  }
  validation {
    condition = alltrue(flatten([
      for p in var.workers : [
        for t in p.taints : can(regex("^[^=]+=[^:]*:(NoSchedule|PreferNoSchedule|NoExecute)$", t))
      ]
    ]))
    error_message = "Taints must be of the form key=value:Effect (NoSchedule, PreferNoSchedule, NoExecute)."
  }
}

variable "k8s_version" {
  description = "Kubernetes minor version from pkgs.k8s.io."
  type        = string
  default     = "1.31"
}

variable "cni" {
  description = "Container network plugin."
  type        = string
  default     = "flannel"

  validation {
    condition     = var.cni == "flannel"
    error_message = "Only flannel is supported at this time."
  }
}

variable "pod_cidr" {
  description = "Pod network CIDR."
  type        = string
  default     = "10.244.0.0/16"
}

variable "svc_cidr" {
  description = "Service ClusterIP CIDR."
  type        = string
  default     = "10.96.0.0/12"
}

variable "data_cidr" {
  description = "Cluster data-plane CIDR on the L2Bridge. Node and load-balancer addresses are assigned from it."
  type        = string
  default     = "10.42.0.0/24"
}

variable "storage" {
  description = "Persistent storage provider."
  type        = string
  default     = "longhorn"

  validation {
    condition     = contains(["longhorn", "none"], var.storage)
    error_message = "storage must be one of: longhorn, none."
  }
}

variable "lb" {
  description = "Load-balancer provider. metallb advertises addresses from data_cidr over the data plane."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["metallb", "none"], var.lb)
    error_message = "lb must be one of: metallb, none."
  }
}

variable "ingress" {
  description = "Install ingress-nginx. Requires lb = metallb."
  type        = bool
  default     = false
}

variable "monitoring" {
  description = "kube-prometheus-stack configuration."
  type = object({
    enabled    = optional(bool, false)
    kubernetes = optional(bool, true)
    nodes      = optional(bool, true)
    dashboards = optional(list(string), ["kubernetes-cluster", "node-exporter", "kubernetes-pods"])
  })
  default = {}
}

variable "manifests" {
  description = "Local paths to manifest files applied after the cluster is ready."
  type        = list(string)
  default     = []
}

variable "helm_charts" {
  description = "Helm releases. chart is a local path or a chart name with repo set."
  type = list(object({
    name        = string
    chart       = string
    repo        = optional(string)
    version     = optional(string)
    namespace   = optional(string, "default")
    values      = optional(any, {})
    values_file = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for c in var.helm_charts :
      can(regex("^(\\./|\\.\\./|/)", c.chart)) || c.repo != null
    ])
    error_message = "Each helm chart must be a local path (./, ../, /) or a chart name with repo set."
  }
  validation {
    condition     = alltrue([for c in var.helm_charts : !can(regex("^https?://", c.chart))])
    error_message = "helm_charts.chart must not be a URL. Use a chart name with repo, or a local path."
  }
}

variable "ssh" {
  description = "SSH access. Defaults suit a standard fablib configuration; bastion fields are auto-discovered when null."
  type = object({
    username            = optional(string, "ubuntu")
    private_key_path    = optional(string)
    bastion_host        = optional(string)
    bastion_username    = optional(string)
    bastion_private_key = optional(string)
  })
  default = {}
}

variable "timeouts" {
  description = "Operation timeouts."
  type = object({
    slice = optional(string, "30m")
    node  = optional(string, "20m")
    helm  = optional(string, "10m")
  })
  default = {}
}

variable "kubeconfig_path" {
  description = "Local path to write the fetched kubeconfig. Defaults to <name>.kubeconfig in the root module directory."
  type        = string
  default     = null
}
