provider "aws" {
  region = "us-west-2"
}

variable "ImageID" {
  default = "ami-06f2f779464715dc5"
}

# SSH RSA key
resource "tls_private_key" "self_signed" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "CTFServer" {
  key_name   = "CTFServer"
  public_key = "${tls_private_key.self_signed.public_key_openssh}"
}

# Firewall Rules
resource "aws_security_group" "CTFServer" {
  name = "CTFServer"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# instance configuration

resource "aws_instance" "CTFServer" {
  #Segment Base 
  ami                                  = "${var.ImageID}"
  instance_type                        = "t2.medium"
  depends_on                           = ["aws_key_pair.CTFServer"]
  key_name                             = "CTFServer"
  security_groups                      = ["${aws_security_group.CTFServer.name}"]
  instance_initiated_shutdown_behavior = "terminate"


  # Deploy ctfd
  provisioner "remote-exec" {


    inline = [
      "sudo apt update",
      "sudo apt install docker.io -y",
      "sudo docker pull ctfd/ctfd",
      "sudo systemctl enable docker",
      "sudo docker run -d -p80:8000 ctfd/ctfd"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = "${aws_instance.CTFServer.public_ip}"
      private_key = "${tls_private_key.self_signed.private_key_pem}"
    }
  }


}


# SSH Stuff
resource "local_file" "provisioned_pem_file" {
  content  = "${tls_private_key.self_signed.private_key_pem}"
  filename = "terraform.pem"
}

output "PublicIP" {
  value = "ssh ubuntu@${aws_instance.CTFServer.public_ip} -i terraform.pem"
}

output "URL" {
  value = "http://${aws_instance.CTFServer.public_ip}"
}
