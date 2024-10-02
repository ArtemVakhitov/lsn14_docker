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
      image_id = "fd8tvc3529h2cpjvpkr5"
    }
  }

  network_interface {
    subnet_id = "e2lgv5mqm56n8fjkt37q"
    nat = true
  }

  metadata = {
    user-data = "${file("build_meta.txt")}"
  }

  connection {
    host = self.network_interface.0.nat_ip_address
    type = "ssh"
    user = "ubuntu"
    private_key = file("/home/user/.ssh/devops-eng-yandex-kp.pem")
    timeout = "3m"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /tmp && git clone https://github.com/boxfuse/boxfuse-sample-java-war-hello.git",
      "cd /tmp && mvn package"
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
      image_id = "fd8tvc3529h2cpjvpkr5"
    }
  }

  network_interface {
    subnet_id = "e2lgv5mqm56n8fjkt37q"
    nat = true
  }

  metadata = {
    user-data = "${file("deploy_meta.txt")}"
  }

  connection {
    host = self.network_interface.0.nat_ip_address
    type = "ssh"
    user = "ubuntu"
    private_key = file("/home/user/.ssh/devops-eng-yandex-kp.pem")
    timeout = "3m"
  }

}
