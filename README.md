# EKS GitOps Observability

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/d163639e-087b-4ddb-b0f9-339968964564" />


> **Part 1 of a 3-project AWS Observability & Cost Governance Platform**

| Repository | Purpose |
|------------|---------|
| **eks-gitops-observability** *(this repository)* | GitOps-driven observability platform on Amazon EKS |
| **multi-account-observability** | Secure cross-account IAM trust for centralised monitoring and cost governance |
| **cost-governance-platform** | Cross-account cost analytics, anomaly detection, and orphaned resource discovery |

---

# Overview

This project builds a **GitOps-driven observability platform** on Amazon EKS where the desired state of the monitoring stack is continuously enforced from Git.

Infrastructure provisioning and application lifecycle management are intentionally separated.

- **Terraform** provisions the AWS infrastructure.
- **ArgoCD** manages every Kubernetes application.
- **Git** remains the single source of truth.

Rather than manually deploying monitoring components with Helm, ArgoCD continuously reconciles the cluster, ensuring configuration drift is automatically detected and corrected.

---

# Architecture

```text
                           Git Repository
                                 │
                                 │ Git Push
                                 ▼
                       GitHub Actions (Validation)
                                 │
                                 ▼
                          ArgoCD (GitOps Engine)
                    Continuous Sync • Self-Heal • Prune
                                 │
                                 ▼
                   Amazon EKS Observability Platform
                                 │
     ┌───────────────────────────┼───────────────────────────┐
     │                           │                           │
     ▼                           ▼                           ▼
 Prometheus                 Alertmanager                 Grafana
 Metrics Collection         Alert Routing              Dashboards
     │                           │                           │
     │                           ▼                           │
     │                     Slack Notifications               │
     │                                                       │
     └────────────── Kubernetes Metrics & Alerts ────────────┘

Terraform provisions:

• VPC
• Amazon EKS
• IAM
• Amazon EKS Pod Identity
• KMS Encryption
• AWS Load Balancer Controller
• ArgoCD Bootstrap

Everything after ArgoCD is managed exclusively from Git.
```

---

# Infrastructure Components

Terraform provisions:

- Amazon VPC
- Amazon EKS
- Managed Node Groups
- IAM Roles
- Amazon EKS Pod Identity
- AWS Load Balancer Controller
- AWS KMS Encryption
- ArgoCD Bootstrap

Once ArgoCD is deployed, responsibility shifts entirely to GitOps.

ArgoCD continuously deploys and reconciles:

- kube-prometheus-stack
- Prometheus
- Grafana
- Alertmanager
- Node Exporter
- Grafana Dashboards
- Prometheus Alert Rules

---

# Why GitOps?

Traditional Helm deployments create working infrastructure but lack continuous reconciliation.

If someone manually changes a Kubernetes resource, the cluster gradually drifts away from the documented configuration.

GitOps eliminates that problem.

Benefits include:

- Git becomes the single source of truth
- Automatic drift detection
- Self-healing reconciliation
- Version-controlled infrastructure
- Simple Git-based rollbacks
- Fully auditable deployments

Every desired state exists in source control—not in terminal history.

---

# Why Amazon EKS Pod Identity?

This project uses **Amazon EKS Pod Identity** instead of IRSA.

Pod Identity is AWS's recommended authentication model for EKS because it:

- Simplifies IAM trust relationships
- Removes cluster-specific OIDC configuration
- Reduces operational complexity
- Improves long-term maintainability

The AWS Load Balancer Controller authenticates using Pod Identity rather than static credentials.

---

# Monitoring Stack

The platform deploys a complete Kubernetes observability solution.

## Prometheus

- Kubernetes metrics collection
- Node monitoring
- Pod monitoring
- Service monitoring

---

## Alertmanager

Routes operational alerts directly to Slack.

Alert definitions include:

- Node health
- Pod CrashLoopBackOff
- Alertmanager health
- Platform availability
- Infrastructure monitoring

---

## Grafana

Provides centralized dashboards for:

- Cluster health
- Infrastructure metrics
- Workload visibility
- Platform performance

Dashboards are automatically discovered using ConfigMap labels and deployed through GitOps.

---

# Repository Structure

```text
terraform/
├── VPC
├── Amazon EKS
├── IAM
├── Pod Identity
├── ALB Controller
└── ArgoCD Bootstrap

manifests/
├── argocd/
├── prometheus/
├── grafana/
├── alertmanager/
├── dashboards/
└── alerts/
```

---

# Deployment

Initialize Terraform.

```bash
cd terraform

terraform init

terraform apply
```

If the initial apply completes before the Kubernetes API becomes available, simply re-run:

```bash
terraform apply
```

Configure kubectl.

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name gitops-observability
```

Retrieve the ArgoCD admin password.

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
-o jsonpath='{.data.password}' | base64 -d
```

---

# Teardown

Destroy the infrastructure.

```bash
cd terraform

terraform destroy
```

For a clean GitOps teardown before infrastructure removal:

```bash
kubectl -n argocd delete application root-app --cascade=foreground
```

---

# Validation

The infrastructure has been validated against a live AWS environment.

Successfully verified:

- VPC provisioning
- Amazon EKS deployment
- IAM configuration
- AWS KMS encryption
- Amazon EKS Pod Identity
- AWS Load Balancer Controller
- ArgoCD bootstrap
- Terraform deployment lifecycle
- Terraform destroy lifecycle

The project completed a full:

- terraform init
- terraform validate
- terraform plan
- terraform apply
- terraform destroy

workflow on AWS.

---

# Current Status

## Completed

- VPC provisioning
- Amazon EKS cluster
- IAM roles
- Amazon EKS Pod Identity
- AWS KMS encryption
- AWS Load Balancer Controller
- ArgoCD bootstrap
- Terraform validation
- Infrastructure lifecycle testing

## In Progress

The managed node group deployment is currently blocked by an **AWS EC2 Fleet Requests service quota**.

Troubleshooting confirmed:

- The EKS control plane provisions successfully.
- IAM configuration is correct.
- Networking is healthy.
- Manual EC2 instance launches succeed.
- Node group failures are isolated to the AWS account quota.
- An AWS Support case has been opened requesting the quota increase.

Development continues in parallel.

ArgoCD Applications, Prometheus alert rules, Grafana dashboards, and Kubernetes manifests are all validated independently through CI and do not depend on the node group being available.

---

# Key Design Principles

- GitOps-first architecture
- Infrastructure as Code
- Declarative Kubernetes
- Continuous reconciliation
- Self-healing deployments
- Immutable infrastructure
- Secure identity with Amazon EKS Pod Identity
- Automated monitoring and alerting
- Production-oriented platform design

---

# Tech Stack

- Terraform
- Amazon EKS
- Kubernetes
- ArgoCD
- Helm
- Prometheus
- Grafana
- Alertmanager
- Amazon EKS Pod Identity
- IAM
- AWS KMS
- AWS Load Balancer Controller
- GitHub Actions
- Slack

---

# Related Projects

This repository is part of a complete AWS observability platform.

| Repository | Description |
|------------|-------------|
| **eks-gitops-observability** | GitOps-managed observability platform using Amazon EKS, ArgoCD, Prometheus, Grafana, and Alertmanager |
| **multi-account-observability** | Secure cross-account IAM trust for centralized monitoring and cost governance |
| **cost-governance-platform** *(Coming Soon)* | Cross-account cost analysis, anomaly detection, and orphaned resource scanning powered by the observability platform and cross-account IAM architecture |
