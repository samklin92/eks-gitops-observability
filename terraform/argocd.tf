resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }

  depends_on = [module.eks]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_chart_version

  # Server runs ClusterIP behind the ALB controller rather than its own LB,
  # matching the pattern the rest of the stack will use for ingress.
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true" # TLS terminated at the ALB; simplifies the demo ingress
  }

  depends_on = [helm_release.alb_controller]
}

# Root "App of Apps" - this is the single manifest applied manually once.
# Everything downstream (kube-prometheus-stack, dashboards, alert rules)
# is reconciled by ArgoCD from Git after this point, not by Terraform.
resource "kubernetes_manifest" "argocd_root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root-app"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/samklin92/eks-gitops-observability.git"
        targetRevision = "main"
        path           = "argocd/bootstrap"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}