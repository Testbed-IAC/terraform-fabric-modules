# k8s

A kubeadm Kubernetes cluster on a FABRIC slice.

All nodes are placed at one site and connected by an L2Bridge data plane. The
module creates the slice, configures each node, runs `kubeadm`, installs the
selected add-ons, and applies your manifests and Helm releases. The apply
finishes only after the cluster and add-ons report ready.

## Requirements

- A FABRIC token (provider configuration or `FABRIC_TOKEN_LOCATION`).
- The FABRIC bastion private key and the node private key on the machine running
  Terraform. The bastion host and username are read from the token; key paths
  default to a standard fablib layout and can be overridden with `ssh`.
- `bash`, `ssh`, and `kubectl` available locally (used to fetch the kubeconfig
  and for the access commands).

## Usage

```hcl
module "k8s" {
  source  = "github.com/Testbed-IAC/terraform-fabric-modules//k8s"
  name    = "my-cluster"
  site    = "STAR"
  ssh_key = file("~/.ssh/id_rsa.pub")
}
```

The first node is the control plane; `workers` defaults to a single worker. See
the [example](../examples/k8s-cluster) for a full configuration.

## Inputs

| Name            | Default         | Description                                                                   |
| --------------- | --------------- | ----------------------------------------------------------------------------- |
| `name`          | —               | Slice and cluster name.                                                       |
| `site`          | —               | FABRIC site; all nodes use it.                                                |
| `ssh_key`       | —               | Public key installed on the nodes.                                            |
| `control_plane` | `{}`            | Control-plane sizing (`cores`, `ram`, `disk`, `image_ref`).                   |
| `workers`       | one worker      | Worker pools: `{ name, count, cores, ram, disk, image_ref, labels, taints }`. |
| `k8s_version`   | `1.31`          | Kubernetes version.                                                           |
| `storage`       | `longhorn`      | `longhorn` or `none`.                                                         |
| `lb`            | `none`          | `metallb` or `none`. Required for `ingress`.                                  |
| `ingress`       | `false`         | Install ingress-nginx.                                                        |
| `monitoring`    | disabled        | kube-prometheus-stack: `{ enabled, kubernetes, nodes, dashboards }`.          |
| `manifests`     | `[]`            | Local manifest paths applied after the cluster is ready.                      |
| `helm_charts`   | `[]`            | Helm releases (local path or chart name with `repo`).                         |
| `ssh`           | fablib defaults | `{ username, private_key_path, bastion_* }`.                                  |
| `timeouts`      | —               | `{ slice, node, helm }`.                                                      |

See `variables.tf` for the full set and defaults.

## Outputs

`kubeconfig`, `kubeconfig_path`, `control_plane_ip`, `worker_ips`,
`data_plane_ips`, `ssh_command`, `api_tunnel_command`, `access_commands`,
`grafana_password`.

## Access

The API server listens on the data-plane address, so use the kubeconfig through
an SSH tunnel:

```sh
eval "$(terraform output -raw api_tunnel_command)" &   # forwards localhost:6443
export KUBECONFIG="$(terraform output -raw kubeconfig_path)"
kubectl get nodes
```

`access_commands` returns one command per web UI. With `lb = "metallb"` they are
`ssh -L` tunnels to a load-balancer address reached through the bastion;
otherwise they are `kubectl port-forward` commands. There are no external IPs.

## Notes

- Single site only: `control_plane.site` and worker pool sites must equal `site`.
- `ingress = true` requires `lb = "metallb"`.
- Pods have no external IPv4 egress. In-cluster DNS works; image and chart pulls
  run on the nodes over IPv6.
- The output commands embed the key paths. On Windows, run them with the system
  OpenSSH (`C:\Windows\System32\OpenSSH\ssh.exe`); the `ssh` bundled with git-bash
  may not read FABRIC's key format.
- This can take up to ~20 minutes per run.
