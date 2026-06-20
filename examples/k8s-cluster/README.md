# k8s-cluster

Control plane + two workers, with Longhorn, MetalLB, ingress-nginx, and
kube-prometheus-stack, plus an example manifest and Helm release.

## Run

    export FABRIC_TOKEN_LOCATION=~/work/fabric_config/id_token.json
    cp terraform.tfvars.example terraform.tfvars   # set site
    terraform init
    terraform apply

Key paths default to `~/work/fabric_config`; override them in `terraform.tfvars`
if yours differ.

## Use

    eval "$(terraform output -raw api_tunnel)" &        # forward the API to localhost:6443
    export KUBECONFIG="$(terraform output -raw kubeconfig_path)"
    kubectl get nodes

    terraform output access_commands                    # ssh -L tunnels to the web UIs
    terraform output -raw grafana_password              # Grafana admin password (user: admin)
