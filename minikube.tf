resource "minikube_cluster" "docker" {
  driver       = "docker"
  nodes        = 3
  cluster_name = "home"
  apiserver_port=8443
  
  addons = [
    "default-storageclass",
    "storage-provisioner",
    "dashboard",
    "metrics-server"
  ]
}
