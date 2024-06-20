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

variable "postgres_instance_count" {
  description = "Number of Postgres instances to deploy"
  type        = number
  default     = 3
}

variable "postgres_volume_size" {
  description = "Size of the volume for Postgres"
  type        = number
  default     = 5
}

resource "kubernetes_persistent_volume" "postgres_volume" {
  count = var.postgres_instance_count

  metadata {
    name = "postgres-volume-${count.index}"
    labels = {
      type = "local"
      app = "postgres"
    }
  }

  spec {
    storage_class_name = "manual"
    capacity = {
      storage = "${var.postgres_volume_size}Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/data/postgresql"
      }
    }
  }
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
}

resource "kubernetes_stateful_set" "postgres_stateful_set" {
  metadata {
    name      = "postgres"
    namespace = "postgres-cluster"
  }

  spec {
    replicas = var.postgres_instance_count

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
          name              = "postgres"
          image             = "postgres:16-alpine"
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
            name       = "postgres-claim"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "postgres-claim"
        labels = {
          app = "postgres"
        }
      }

      spec {
        storage_class_name = "manual"
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "${var.postgres_volume_size}Gi"
          }
        }
      }
    }

    service_name = kubernetes_service.postgres_service.metadata.0.name
  }

  depends_on = [ 
    kubernetes_service.postgres_service, 
    kubernetes_persistent_volume.postgres_volume
  ]
}
