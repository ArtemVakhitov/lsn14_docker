terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    # docker = {
    #   source  = "kreuzwerker/docker"
    #   version = "3.0.2"
    # }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-b"
}

# resource "null_resource" "create_build_key" {
#   provisioner "local-exec" {
#     command = <<-EOT
# 		ssh-keygen -b 2048 -f ${path.module}/build -N ""
# 	EOT
#   }
# }

# data "local_sensitive_file" "build_private_key" {
#   filename = "${path.module}/build"
#   depends_on = [null_resource.create_build_key]
# }

# data "local_file" "build_public_key" {
#   filename = "${path.module}/build.pub"
#   depends_on = [null_resource.create_build_key]
# }

# resource "null_resource" "create_deploy_key" {
#   provisioner "local-exec" {
#     command = <<-EOT
# 		ssh-keygen -b 2048 -f ${path.module}/deploy -N ""
# 	EOT
#   }
# }

# data "local_sensitive_file" "deploy_private_key" {
#   filename = "${path.module}/deploy"
#   depends_on = [null_resource.create_deploy_key]
# }

# data "local_file" "deploy_public_key" {
#   filename = "${path.module}/deploy.pub"
#   depends_on = [null_resource.create_deploy_key]
# }

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
    user-data = file("metadata.yml")
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y git maven docker.io",
      "cd /tmp && git clone https://github.com/boxfuse/boxfuse-sample-java-war-hello.git",
      "cd /tmp/boxfuse-sample-java-war-hello && mvn package"
    ]
    connection {
      host = self.network_interface.0.nat_ip_address
      type = "ssh"
      user = "root"
      private_key = file("~/.ssh/devops-eng-yandex-kp.pem")
    }

  }

}

# provider "docker" {
#   host = "ssh://ubuntu@${yandex_compute_instance.build.network_interface.0.nat_ip_address}:22"
#   ssh_opts = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"]
# }


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
    user-data = file("metadata.yml")
  }

  connection {
    host = self.network_interface.0.nat_ip_address
    type = "ssh"
    user = "root"
    private_key = file("~/.ssh/devops-eng-yandex-kp.pem")
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y tomcat9"
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
		scp -i ~/.ssh/devops-eng-yandex-kp.pem -P 22 -o "StrictHostKeyChecking=no" root@${yandex_compute_instance.build.network_interface.0.nat_ip_address}:/tmp/boxfuse-sample-java-war-hello/target/hello-1.0.war /tmp/
		scp -i ~/.ssh/devops-eng-yandex-kp.pem -P 22 -o "StrictHostKeyChecking=no" /tmp/hello-1.0.war root@${self.network_interface.0.nat_ip_address}:/tmp/
	EOT
  }

  provisioner "remote-exec" {
    inline = [
      "cp /tmp/hello-1.0.war /var/lib/tomcat9/webapps/"
    ]
  }

  depends_on = [yandex_compute_instance.build]

}

# resource "null_resource" "destroy_keys" {
#   provisioner "local-exec" {
#     command = <<-EOT
# 			rm -f build* deploy*
# 		EOT
#     when = destroy
#   }
# }