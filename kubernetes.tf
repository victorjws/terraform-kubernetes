resource "aws_vpc" "app_vpc" {
  enable_dns_hostnames = true
  enable_dns_support   = true
  cidr_block           = "10.0.0.0/16"

  tags = {
    project = var.project_name
  }
}

resource "aws_subnet" "app_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.app_vpc.cidr_block, 3, 1)
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    project = var.project_name
  }
}

resource "aws_eip" "master-eip" {
  instance = aws_instance.master.id
  vpc      = true
}

resource "aws_eip" "node1-eip" {
  instance = aws_instance.node1.id
  vpc      = true
}

resource "aws_eip" "node2-eip" {
  instance = aws_instance.node2.id
  vpc      = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    project = var.project_name
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    project = var.project_name
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    project = var.project_name
  }
}

resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "ssh_key"
  public_key = tls_private_key.pk.public_key_openssh
  tags = {
    project = var.project_name
  }
}

resource "aws_instance" "master" {
  ami           = "ami-058165de3b7202099"
  instance_type = "t2.medium"
  key_name      = aws_key_pair.ssh_key_pair.key_name

  subnet_id       = aws_subnet.app_subnet.id
  security_groups = [aws_security_group.allow_ssh.id]

  tags = {
    project = var.project_name
  }
}

resource "aws_instance" "node1" {
  ami           = "ami-058165de3b7202099"
  instance_type = "t2.medium"
  key_name      = aws_key_pair.ssh_key_pair.key_name

  subnet_id       = aws_subnet.app_subnet.id
  security_groups = [aws_security_group.allow_ssh.id]

  tags = {
    project = var.project_name
  }
}

resource "aws_instance" "node2" {
  ami           = "ami-058165de3b7202099"
  instance_type = "t2.medium"
  key_name      = aws_key_pair.ssh_key_pair.key_name

  subnet_id       = aws_subnet.app_subnet.id
  security_groups = [aws_security_group.allow_ssh.id]

  tags = {
    project = var.project_name
  }
}