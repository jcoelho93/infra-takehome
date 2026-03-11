terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.26"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_container" "postgres" {
  name  = "postgres-infra-takehome"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=app",
  ]

  ports {
    internal = 5432
    external = var.postgres_port
  }

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  restart = "unless-stopped"
}

resource "docker_volume" "postgres_data" {
  name = "postgres-infra-takehome-data"
}

resource "terraform_data" "wait_for_postgres" {
  provisioner "local-exec" {
    command = <<EOT
      for i in {1..60}; do
        if pg_isready -h localhost -p ${var.postgres_port} -U postgres; then
          exit 0
        fi
        echo "Waiting for postgres..."
        sleep 2
      done
      echo "Postgres did not become ready in time" >&2
      exit 1
    EOT
    environment = {
      PGPASSWORD = var.postgres_password
    }
  }
  depends_on = [docker_container.postgres]
}

resource "postgresql_database" "postgrest" {
  name       = "postgrest"
  #owner      = postgresql_role.admin.name
  depends_on = [terraform_data.wait_for_postgres, docker_container.postgres]
}

resource "postgresql_role" "admin" {
  name       = "admin"
  password   = var.postgres_password
  login      = true

  superuser  = true

  skip_drop_role = true
  skip_reassign_owned = true

  depends_on = [terraform_data.wait_for_postgres, docker_container.postgres]
}

resource "kubernetes_secret_v1" "postgrest" {
  metadata {
    name      = "postgrest-secrets"
    namespace = "postgrest"
  }
  type = "Opaque"
  data = {
    uri = "postgresql://admin:${var.postgres_password}@host.k3d.internal:${var.postgres_port}/app"
  }
}
