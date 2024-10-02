terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.6"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-b"
}

provider "tls" {
  # Configuration options
}

resource "tls_private_key" "build_key" {
  algorithm = "ED25519"
}

resource "yandex_compute_instance" "build" {

  name = "build"

  zone = "ru-central1-b"
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd874d4jo8jbroqs6d7i"
    }
  }

  network_interface {
    subnet_id = "e2lgv5mqm56n8fjkt37q"
    nat = true
  }

  metadata = {
    ssh-keys = tls_private_key.build_key.public_key_openssh
  }

  provisioner "local-exec" { 
    command = <<-EOT
		echo '${tls_private_key.build_key.private_key_openssh}' > ./build.pem
		chmod 400 ./build.pem
	EOT
  }

  connection {
    host = self.network_interface.0.nat_ip_address
    type = "ssh"
    user = "ubuntu"
    private_key = tls_private_key.build_key.private_key_openssh
    timeout = "3m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y git maven",
      "cd /tmp && git clone https://github.com/boxfuse/boxfuse-sample-java-war-hello.git",
      "cd /tmp/boxfuse-sample-java-war-hello && mvn package"
    ]
    
  }

}

resource "tls_private_key" "deploy_key" {
  algorithm = "ED25519"
}

resource "yandex_compute_instance" "deploy" {

  name = "deploy"

  zone = "ru-central1-b"
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd874d4jo8jbroqs6d7i"
    }
  }

  network_interface {
    subnet_id = "e2lgv5mqm56n8fjkt37q"
    nat = true
  }

  metadata = {
    ssh-keys = tls_private_key.deploy_key.public_key_openssh
  }

  provisioner "local-exec" { 
    command = <<-EOT
		echo '${tls_private_key.deploy_key.private_key_openssh}' > ./deploy.pem
		chmod 400 ./deploy.pem
	EOT
  }

  connection {
    host = self.network_interface.0.nat_ip_address
    type = "ssh"
    user = "ubuntu"
    private_key = tls_private_key.deploy_key.private_key_openssh
    timeout = "3m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y tomcat9"
    ]
  }

}
