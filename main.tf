# --------------------------------------------------------------
# Provider
# --------------------------------------------------------------

provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
}

# --------------------------------------------------------------
# Data
# --------------------------------------------------------------

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

# --------------------------------------------------------------
# Resources
# --------------------------------------------------------------

resource "aws_key_pair" "site_key" {
  public_key = "${file("~/.ssh/id_rsa.pub")}"
  key_name   = "urchin_default_key"
}

resource "aws_security_group" "allow_all" {
  name        = "urchin_allow_all"
  description = "Allow all inbound traffic to your Urchin instance"
  vpc_id      = "${aws_vpc.urchin.id}"

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

resource "aws_vpc" "urchin" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name = "Urchin_VPC"
  }
}

resource "aws_internet_gateway" "public" {
  vpc_id = "${aws_vpc.urchin.id}"

  tags {
    Name = "Urchin_gw"
  }
}

resource "aws_subnet" "urchin" {
  availability_zone = ""
  cidr_block        = "10.0.1.0/24"
  vpc_id            = "${aws_vpc.urchin.id}"

  tags {
    Name = "Urchin"
  }

  lifecycle {
    create_before_destroy = true
  }

  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.urchin.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.public.id}"
  }

  tags {
    Name = "Urchin_public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.urchin.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_efs_file_system" "storage" {
  encrypted = true

  tags {
    Name = "Urchin_Data"
  }
}

resource "aws_efs_mount_target" "mount" {
  file_system_id  = "${aws_efs_file_system.storage.id}"
  subnet_id       = "${aws_subnet.urchin.id}"
  security_groups = ["${aws_security_group.allow_all.id}"]
}

resource "aws_instance" "urchin_node" {
  ami                    = "${data.aws_ami.base_image.id}"
  instance_type          = "${var.specs["type"]}"
  vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]
  subnet_id              = "${aws_subnet.urchin.id}"
  key_name               = "${aws_key_pair.site_key.key_name}"
  depends_on             = ["aws_efs_mount_target.mount"]

  tags {
    Name = "${var.specs["name"]}"
  }

  //  user_data = "${data.template_file.user_data.rendered}"
  provisioner "remote-exec" {
    inline = [
      "mkdir storage",
      "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${aws_efs_mount_target.mount.dns_name}:/ /home/ubuntu/storage",
      "docker run -d --rm -v '/home/ubuntu/storage:/home/jovyan/work' -p 80:8888 jupyter/scipy-notebook start-notebook.sh --NotebookApp.token=${var.password}",
    ]

    connection {
      user        = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
}
