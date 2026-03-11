terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

resource "kubernetes_deployment_v1" "postgrest" {
  metadata {
    name      = "postgrest"
    namespace = "postgrest"
    labels = {
      app = "postgrest"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgrest"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgrest"
        }
      }

      spec {
        host_network = true
        dns_policy   = "ClusterFirstWithHostNet"

        container {
          name  = "postgrest"
          image = "postgrest/postgrest"

          port {
            container_port = 3000
          }

          env {
            name = "PGRST_DB_URI"

            value_from {
              secret_key_ref {
                name = "postgrest-secrets"
                key  = "uri"
              }
            }
          }

          env {
            name  = "PGRST_DB_ANON_ROLE"
            value = "admin" # yes, this is not recommended
          }

          env {
            name  = "PGRST_DB_SCHEMA"
            value = "public"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgrest" {
  metadata {
    name      = "postgrest"
    namespace = "postgrest"
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = "postgrest"
    }
    port {
      port        = 3000
      target_port = 3000
    }
  }
}

resource "kubernetes_ingress_v1" "postgrest" {
  metadata {
    name = "postgrest"
    namespace = "postgrest"
  }
  spec {
    rule {
      host = "postgrest.localhost"
      http {
        path {
          path = "/"
          backend {
            service {
              name = "postgrest"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_config_map_v1" "insert_data_script" {
  metadata {
    name      = "insert-data-script"
    namespace = "postgrest"
  }

  data = {
    "insert_data.sql" = <<SQL
CREATE TABLE IF NOT EXISTS argocd_apps (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  namespace TEXT NOT NULL,
  repo_url TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO argocd_apps (name, namespace, repo_url) VALUES
  ('app1', 'default', 'https://github.com/fake/app.git'),
  ('app2', 'argocd', 'https://github.com/fake/app2.git'),
  ('app3', 'prod', 'https://github.com/fake/app3.git');

NOTIFY pgrst, 'reload schema';
SQL
  }

}

resource "kubernetes_job_v1" "postgrest_data_injector" {
  metadata {
    name      = "postgrest-data-injector"
    namespace = "postgrest"
  }

  spec {
    template {
      metadata {
        labels = {
          job = "postgrest-data-injector"
        }
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "injector"
          image = "postgres:16-alpine"

          command = ["/bin/sh", "-c", "psql $URI -f /scripts/insert_data.sql"]

          env {
            name = "URI"
            value_from {
              secret_key_ref {
                name = "postgrest-secrets"
                key  = "uri"
              }
            }
          }

          volume_mount {
            name       = "script-volume"
            mount_path = "/scripts"
          }
        }

        volume {
          name = "script-volume"

          config_map {
            name = kubernetes_config_map_v1.insert_data_script.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map_v1.insert_data_script
  ]
}
