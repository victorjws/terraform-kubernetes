resource "aws_vpc" "app_vpc" {
  enable_dns_hostnames = true
  enable_dns_support   = true
  cidr_block           = "10.0.0.0/16"

  tags = {
    project = var.project_name
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.app_vpc.cidr_block, 3, 1)
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    project = var.project_name
    network = var.public_network
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.app_vpc.cidr_block, 3, 2)
  availability_zone = var.availability_zone

  tags = {
    project = var.project_name
    network = var.private_network
  }
}

resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  vpc      = true
  tags = {
    project = var.project_name
    network = var.public_network
    name    = "bastion-eip"
  }
}

resource "aws_eip" "nat_gateway_eip" {
  vpc = true
  tags = {
    project = var.project_name
    network = var.public_network
    name    = "nat-gateway-eip"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    project = var.project_name
    network = var.public_network
  }
}

resource "aws_nat_gateway" "public_nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    project = var.project_name
    network = var.public_network
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public_rtb" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    project = var.project_name
    network = var.public_network
  }
}

resource "aws_route_table" "private_rtb" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.public_nat_gateway.id
  }

  tags = {
    project = var.project_name
    network = var.private_network
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rtb.id
}

resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rtb.id
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "ICMP from VPC"
    from_port        = 0
    to_port          = 255
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    project = var.project_name
    network = var.public_network
  }
}

resource "aws_security_group" "allow_bastion" {
  name        = "allow_bastion"
  description = "Allow SSH from bastion"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_ssh.id]
  }

  ingress {
    description     = "ICMP from bastion"
    from_port       = 0
    to_port         = 255
    protocol        = "icmp"
    security_groups = [aws_security_group.allow_ssh.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    project = var.project_name
    network = var.private_network
  }
}

resource "aws_security_group" "k8s_control_plane" {
  # https://kubernetes.io/docs/reference/ports-and-protocols/
  name        = "k8s_control_plane"
  description = "Allow kubernetes inbound traffic for control plane"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description      = "Kubernetes API server"
    from_port        = 6443
    to_port          = 6443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "etcd server client API"
    from_port        = 2379
    to_port          = 2380
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Kubelet API"
    from_port        = 10250
    to_port          = 10250
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "kube-scheduler"
    from_port        = 10259
    to_port          = 10259
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "kube-controller-manager"
    from_port        = 10257
    to_port          = 10257
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    project = var.project_name
    network = var.private_network
  }
}

resource "aws_security_group" "k8s_worker_node" {
  # https://kubernetes.io/docs/reference/ports-and-protocols/
  name        = "k8s_worker_node"
  description = "Allow kubernetes inbound traffic for worker nodes"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description      = "Kubelet API"
    from_port        = 10250
    to_port          = 10250
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "NodePort Services"
    from_port        = 30000
    to_port          = 32767
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    project = var.project_name
    network = var.private_network
  }
}

resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "ssh_key"
  public_key = tls_private_key.pk.public_key_openssh
  tags = {
    project = var.project_name
  }
}

resource "aws_instance" "bastion" {
  ami           = "ami-058165de3b7202099"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ssh_key_pair.key_name

  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.allow_ssh.id]

  tags = {
    project = var.project_name
    network = var.public_network
  }
}

resource "aws_instance" "master" {
  ami           = "ami-058165de3b7202099"
  instance_type = "t2.medium"
  key_name      = aws_key_pair.ssh_key_pair.key_name

  subnet_id       = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.k8s_control_plane.id, aws_security_group.allow_bastion.id]

  tags = {
    project = var.project_name
    network = var.private_network
  }
}

resource "aws_instance" "node1" {
  ami           = "ami-058165de3b7202099"
  instance_type = "t2.medium"
  key_name      = aws_key_pair.ssh_key_pair.key_name

  subnet_id       = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.k8s_worker_node.id, aws_security_group.allow_bastion.id]

  tags = {
    project = var.project_name
    network = var.private_network
  }
}

resource "aws_instance" "node2" {
  ami           = "ami-058165de3b7202099"
  instance_type = "t2.medium"
  key_name      = aws_key_pair.ssh_key_pair.key_name

  subnet_id       = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.k8s_worker_node.id, aws_security_group.allow_bastion.id]

  tags = {
    project = var.project_name
    network = var.private_network
  }
}
