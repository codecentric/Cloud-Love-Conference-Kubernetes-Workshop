provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "kubernetes_namespace" "user-namespaces" {
  for_each = var.users
  metadata {
    name = each.key
  }
}

resource "kubernetes_role" "user-role" {
  for_each   = var.users
  depends_on = [kubernetes_namespace.user-namespaces]
  metadata {
    namespace = each.key
    name      = each.key
  }
  rule {
    api_groups = [
      "",
      "apps"
    ]
    verbs = [
      "get",
      "watch",
      "list",
      "edit",
      "create",
      "delete",
      "deletecollection",
      "patch",
      "update"
    ]
    resources = [
      "pods",
      "daemonsets",
      "deployments",
      "pods/log",
      "pods/exec",
      "replicasets",
      "statefulsets",
      "ingresses",
      "services",
      "configmaps",
      "secrets",
      "persistentvolumeclaims"
    ]
  }
}

resource "kubernetes_service_account" "user-account" {
  for_each   = var.users
  depends_on = [kubernetes_namespace.user-namespaces]
  metadata {
    namespace = each.value
    name      = each.value
  }
}

resource "kubernetes_role_binding" "user-role-binding" {
  for_each   = var.users
  depends_on = [kubernetes_service_account.user-account, kubernetes_role.user-role]
  metadata {
    namespace = each.value
    name      = each.value
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = each.value
  }
  subject {
    kind      = "ServiceAccount"
    name      = each.value
    namespace = each.value
  }
}

resource "kubernetes_config_map" "aws-auth" {
  metadata {
    namespace = "kube-system"
    name      = "aws-auth"
  }

  data = {
    mapUsers = file("${path.module}/mapUsers.yaml")
  }


}


data "kubernetes_secret" "user-secret" {
  for_each = kubernetes_service_account.user-account
  metadata {
    namespace = each.value.metadata.0.namespace
    name      = each.value.default_secret_name
  }
}