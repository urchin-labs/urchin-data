provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
}

data "aws_ami" "base_image" {
  most_recent = true
  owners      = ["681990645369"]

  filter {
    name   = "tag:Application"
    values = ["Jupyter"]
  }

  filter {
    name   = "tag:Manufacturer"
    values = ["Urchin"]
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/config/user_data.txt")}"

  vars {
    password = "${var.password}"
  }
}

resource "aws_key_pair" "site_key" {
  public_key = "${file("~/.ssh/id_rsa.pub")}"
  key_name   = "urchin_default_key"
}

// create a default security group
resource "aws_security_group" "allow_all" {
  name        = "urchin_allow_all"
  description = "Allow all inbound traffic to your Urchin instance"

  ingress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "urchin_allow_all"
  }
}

// Build the instance and launch Ansible to configure it
resource "aws_instance" "urchin_node" {
  ami           = "${data.aws_ami.base_image.id}"
  instance_type = "${var.specs["type"]}"

  tags {
    Name = "${var.specs["name"]}"
  }

  security_groups = ["${aws_security_group.allow_all.name}"]
  key_name        = "${aws_key_pair.site_key.key_name}"

  user_data = "${data.template_file.user_data.rendered}"
}
