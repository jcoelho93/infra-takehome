resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [ terraform_data.k3d_cluster ]
}

resource "terraform_data" "argocd_install" {
    provisioner "local-exec" {
      command = "kubectl apply --server-side -k ${path.module}/../argocd/argocd"
    }
    provisioner "local-exec"  {
        when = destroy
        command = "kubectl delete -k ${path.module}/../argocd/argocd"
    }
    depends_on = [ terraform_data.k3d_cluster, kubernetes_namespace_v1.argocd ]
}
