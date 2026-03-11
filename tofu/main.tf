provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "postgresql" {
  host     = "localhost"
  port     = var.postgres_port
  username = "postgres"
  password = var.postgres_password
  sslmode  = "disable"
}

resource "terraform_data" "k3d_cluster" {
  input = {
    name  = var.k3d_cluster_name
    image = "rancher/k3s:${var.k3s_version}"
  }

  provisioner "local-exec" {
    command = "k3d cluster create ${self.input.name} --image ${self.input.image} --servers 1 --agents 0 -p '8080:80@loadbalancer' && sleep 10"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.input.name}"
  }
}

resource "kubernetes_namespace_v1" "postgrest" {
  metadata {
    name = "postgrest"
  }
}

module "postgres" {
  source = "../postgres"

  depends_on = [terraform_data.k3d_cluster, kubernetes_namespace_v1.postgrest]
}

module "postgrest" {
  source     = "../postgrest"
  depends_on = [terraform_data.k3d_cluster, module.postgres, kubernetes_namespace_v1.postgrest]
}
