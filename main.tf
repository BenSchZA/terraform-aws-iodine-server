provider "aws" {
  region = "eu-west-1"
  profile = "personal"
}

resource "aws_key_pair" "tunnel" {
  key_name   = "tunnel"
  public_key = "${file("/home/bscholtz/.ssh/tunnel.pub")}"
}

resource "aws_security_group" "allow_udp" {
  name        = "allow_udp"
  description = "Allow UDP inbound traffic"

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "UDP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


# Request a spot instance at $0.0057
resource "aws_spot_instance_request" "iodine" {
  ami           = "ami-00035f41c82244dab"
  spot_price    = "0.0057"
  instance_type = "t3.nano"
  wait_for_fulfillment = true
  block_duration_minutes = 360
  key_name = "tunnel"
  security_groups = ["${aws_security_group.allow_udp.name}"]

  tags = {
    Name = "iodine"
  }

  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = "${file("~/.ssh/tunnel.pem")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install iodine",
      "sudo iodined -c 10.0.0.1 -P password tunnel.benjaminscholtz.com",
    ]
  }
}

resource "null_resource" "rerun" {
  triggers {
    rerun = "1"
  }

  connection {
    type = "ssh"
    user = "ubuntu"
    host = "${aws_spot_instance_request.iodine.public_dns}"
    private_key = "${file("~/.ssh/tunnel.pem")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install iodine",
      "sudo iodined -c 10.0.0.1 -P password tunnel.benjaminscholtz.com",
    ]
  }
}

resource "aws_route53_zone" "primary" {
  name = "benjaminscholtz.com."
}

resource "aws_route53_record" "tunnel-ns" {
  zone_id = "${aws_route53_zone.primary.zone_id}"
  name    = "ns.${aws_route53_zone.primary.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_spot_instance_request.iodine.public_ip}"]
}

output "iodine_public-ip" {
  value = "${aws_spot_instance_request.iodine.public_ip}"
}
output "iodine_public-dns" {
  value = "${aws_spot_instance_request.iodine.public_dns}"
}
