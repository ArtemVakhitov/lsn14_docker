terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-b"
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
    private_key = file("./build.pem")
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
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

  connection {
    host = self.network_interface.0.nat_ip_address
    type = "ssh"
    user = "ubuntu"
    private_key = file("~/.ssh/devops-eng-yandex-kp.pem")
    timeout = "3m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y tomcat9"
    ]
  }

}
