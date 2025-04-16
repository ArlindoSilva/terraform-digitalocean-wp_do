terraform {
  required_providers {
    digitalocean = {
        source = "digitalocean/digitalocean"
        version = "~>2.0.0"
    }
  }
}

// Rede privada
resource "digitalocean_vpc" "wp_net" {
  name =  "wp-network"
  region = var.region
}

// Faz o balanceamento de carga entre VMs
resource "digitalocean_loadbalancer" "wp_lb" {
  name = "wp-lb"
  region = var.region

  forwarding_rule {
    //Recebe uma requisição http na porta 80
    entry_port = 80
    entry_protocol = "http"

    //Redireciona para a porta 80 dos servidores
    target_port = 80
    target_protocol = "http"
  }

  healthcheck {
    port = 80
    protocol = "http"
    path = "/"
  }

//vinculando a vpc da chave privada nesse atributo
  vpc_uuid = digitalocean_vpc.wp_net.id

  droplet_ids = digitalocean_droplet.vm_wp[*].id
}

//Criação do droptlet wordpress
resource "digitalocean_droplet" "vm_wp" {
  name = "vm-wp-${count.index + 1}"
  size = "s-2vcpu-2gb"
  image = "ubuntu-22-04-x64"
  region = var.region

  vpc_uuid = digitalocean_vpc.wp_net.id
  count = var.wp_vm_count

  ssh_keys = [var.vms_ssh]
  # ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

//nfsServer, Onde vao ser armazenadas os arquivos do wordpress
resource "digitalocean_droplet" "vm_nfs" {
  name = "vm-nfs"
  size = "s-2vcpu-2gb"
  image = "ubuntu-22-04-x64"
  region = var.region
  vpc_uuid = digitalocean_vpc.wp_net.id
  ssh_keys = [var.vms_ssh]
}

resource "digitalocean_database_db" "wp_database" {
  cluster_id = digitalocean_database_cluster.wp_mysql.id
  name = "wp-database"
}

//Criação de um database
resource "digitalocean_database_cluster" "wp_mysql" {
  name = "wp-mysql"
  engine = "mysql"
  version = 8
  size = "db-s-1vcpu-1gb"
  region = var.region
  node_count = 1
  private_network_uuid = digitalocean_vpc.wp_net.id
}

//Criação de um usuario
resource "digitalocean_database_user" "wp_database_user" {
  cluster_id = digitalocean_database_cluster.wp_mysql.id
  name = "wordpress"
}