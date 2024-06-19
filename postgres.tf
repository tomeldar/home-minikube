resource "kubernetes_namespace" "postgres_namespace" {
  metadata {
    name = "postgres-cluster"
  }
}

resource "kubernetes_config_map" "postgres_config_map" {
  metadata {
    name = "postgres-config"
    namespace = "postgres-cluster"
    labels = {
      app = "postgres"
    }
  }

  data = {
    "POSTGRES_DB"       = var.postgres_db
    "POSTGRES_USER"     = var.postgres_user
    "POSTGRES_PASSWORD" = var.postgres_password
  }
}

resource "kubernetes_persistent_volume" "postgres_volume" {
  metadata {
    name = "postgres-volume"
    labels = {
      type = "local"
      app = "postgres"
    }
  }

  spec {
    storage_class_name = "manual"
    capacity = {
      storage = "10Gi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      host_path {
        path = "/data/postgresql"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  metadata {
    name = "postgres-pvc"
    namespace = "postgres-cluster"
    labels = {
      app = "postgres"
    }
  }

  spec {
    storage_class_name = "manual"
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }

  depends_on = [ kubernetes_persistent_volume.postgres_volume ]
}

resource "kubernetes_deployment" "postgres_deployment" {
  metadata {
    name = "postgres"
    namespace = "postgres-cluster"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name = "postgres"
          image = "postgres:16-alpine"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 5432
          }
          env_from {
            config_map_ref {
              name = kubernetes_config_map.postgres_config_map.metadata.0.name
            }
          }

          volume_mount {
            name = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "postgres-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata.0.name
          }
        }
      }
    }
  }

  depends_on = [ kubernetes_persistent_volume_claim.postgres_pvc ]
}

resource "kubernetes_service" "postgres_service" {
  metadata {
    name = "postgres"
    namespace = "postgres-cluster"
    labels = {
      app = "postgres"
    }
  }

  spec {
    type = "NodePort"
    selector = {
      app = "postgres"
    }

    port {
      port = 5432
    }
  }

  depends_on = [ kubernetes_deployment.postgres_deployment ]
}
