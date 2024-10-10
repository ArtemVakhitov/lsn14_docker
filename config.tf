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

variable "docker_secret" {
  type = string
  sensitive = true
  default = ""
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

  connection {
    host = self.network_interface.0.nat_ip_address
    type = "ssh"
    user = "root"
    private_key = file("~/.ssh/devops-eng-yandex-kp.pem")
  }

  provisioner "file" {
    source = "Dockerfile"
    destination = "/root/Dockerfile"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y git maven docker.io",
      "git clone https://github.com/boxfuse/boxfuse-sample-java-war-hello.git",
      "cd boxfuse-sample-java-war-hello",
      "mvn package",
      "echo ${var.docker_secret} | docker login -u artemvakhitov --password-stdin",
      "docker build -t lsn14 -f ../Dockerfile .",
      "docker tag lsn14 artemvakhitov/lsn14",
      "docker push artemvakhitov/lsn14"
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
      "apt-get install -y docker.io",
      "docker run -d -p 8080:8080 artemvakhitov/lsn14"
    ]
  }

  depends_on = [yandex_compute_instance.build]

}

resource "null_resource" "manage_inputs" {

  # Currently, Terraform asks for inputs at `destroy` and refuses to proceed if they don't match.
  # A corresponding bug was filed on GitHub long ago which is still not fixed.
  # This will handle writing .auto.tfvars file so you can simply `terraform destroy`.
  # Additionally, the docker secret can be used on subsequent runs.

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOT
			if [ ! -f vms.auto.tfvars ]; then printf "docker_secret = %s\n" "\"${var.docker_secret}\"" > vms.auto.tfvars; fi
		EOT
    when = create
  }

}

# resource "null_resource" "destroy_keys" {
#   provisioner "local-exec" {
#     command = <<-EOT
# 			rm -f build* deploy*
# 		EOT
#     when = destroy
#   }
# }