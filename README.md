# eks-gitops-observability

Part of a 3-project observability and cost-governance platform:

1. **eks-gitops-observability** (this repo) — GitOps-driven monitoring on EKS
2. **multi-account-observability** — cross-account metrics aggregation (depends on this repo's Alertmanager)
3. **cost-governance-platform** — trend anomaly detection + orphaned-resource scanning (depends on both above)

## What this is

A monitoring stack on EKS where the desired state lives in Git, not in imperative
`helm install` commands. ArgoCD reconciles Prometheus, Grafana, dashboards, and
alert rules from this repository; Terraform's job stops at standing up the
cluster and the ArgoCD entrypoint itself.

## Architecture

```
Terraform          →  VPC, EKS, Pod Identity, ALB Controller, ArgoCD (bootstrap only)
ArgoCD              →  reconciles everything below from Git
  ├─ kube-prometheus-stack   (Prometheus, Grafana, Alertmanager, node-exporter)
  ├─ dashboards/             (Grafana dashboard JSON, ConfigMap-mounted)
  └─ alerts/                 (PrometheusRule CRDs)
Alertmanager        →  Slack (#alerts)
```

## Why Pod Identity instead of IRSA

EKS Pod Identity supersedes IRSA as of 2023 and is the currently recommended
pattern going into 2026 — simpler trust policy, no per-cluster OIDC provider
plumbing. Used here for the ALB Controller's IAM role.

## Why GitOps instead of `helm install`

A direct `helm install` gives you a running stack with no reconciliation loop —
if someone changes something in-cluster by hand, it silently drifts from what's
in Git. ArgoCD's `selfHeal: true` means the cluster state is provably equal to
the Git state at all times, and a `git revert` is a real rollback mechanism.

## Deploying

```bash
cd terraform
terraform init
terraform apply
# kubernetes_manifest for the ArgoCD root Application depends on the API server
# being reachable — if this errors on first apply, re-run terraform apply once more.

aws eks update-kubeconfig --region us-east-1 --name gitops-observability
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

## Tearing down

```bash
cd terraform
terraform destroy
```

ArgoCD-managed resources (kube-prometheus-stack, etc.) are cleaned up by
`terraform destroy` only insofar as the underlying namespace/cluster goes away
with it — this is a demo teardown, not a graceful ArgoCD app deletion. For a
clean app-level teardown first, run:

```bash
kubectl -n argocd delete application root-app --cascade=foreground
```

## Status

**Terraform layer: validated end-to-end, deployment currently paused on an AWS account restriction.**

The full Terraform stack (VPC, EKS cluster, Pod Identity, ALB Controller, ArgoCD bootstrap)
was run through a complete `init` → `validate` → `plan` → `apply` → `destroy` cycle against
a real AWS account. The EKS cluster, VPC, IAM roles, and KMS encryption all provisioned
successfully and reached `ACTIVE`/healthy state.

The managed node group launch is currently blocked by an account-level EC2 Fleet Requests
quota restriction — a documented AWS pattern where automated fleet-based launches (used by
Auto Scaling Groups and EKS managed node groups) are more tightly gated than manual EC2
launches on certain accounts. Confirmed via:
- `aws eks describe-nodegroup` health output showing `AsgInstanceLaunchFailures`
- A successful manual EC2 console launch on the same account (ruling out a general
  EC2/compute limit)
- An open AWS Support case requesting the limit increase

ArgoCD Application manifests, kube-prometheus-stack values, dashboards, and PrometheusRule
CRDs are the next layer to write — these don't require a live cluster to validate (CI runs
`kubeconform` against them), so that work is proceeding in parallel with the AWS Support
ticket.