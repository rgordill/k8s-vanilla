# =============================================================================
# AWS Infrastructure for Kubernetes (configured by Ansible)
# =============================================================================

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

# Look up the latest Fedora AMI if not specified
data "aws_ami" "fedora" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.fedora[0].id
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "k8s_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "k8s-vanilla-vpc"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "k8s-vanilla-igw"
  }
}

# -----------------------------------------------------------------------------
# Public Subnet
# -----------------------------------------------------------------------------

resource "aws_subnet" "k8s_public" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-vanilla-public-subnet"
  }
}

# -----------------------------------------------------------------------------
# Route Table
# -----------------------------------------------------------------------------

resource "aws_route_table" "k8s_public" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }

  tags = {
    Name = "k8s-vanilla-public-rt"
  }
}

resource "aws_route_table_association" "k8s_public" {
  subnet_id      = aws_subnet.k8s_public.id
  route_table_id = aws_route_table.k8s_public.id
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "k8s_node" {
  name        = "k8s-vanilla-node-sg"
  description = "Security group for Kubernetes node"
  vpc_id      = aws_vpc.k8s_vpc.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API
  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (Ingress)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (Ingress)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort range
  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic within VPC (for Kubernetes internal communication)
  ingress {
    description = "All VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-vanilla-node-sg"
  }
}

# -----------------------------------------------------------------------------
# Key Pair
# -----------------------------------------------------------------------------

resource "aws_key_pair" "k8s_key" {
  key_name   = var.key_pair_name
  public_key = file(var.ssh_public_key_file)

  tags = {
    Name = var.key_pair_name
  }
}

# -----------------------------------------------------------------------------
# EC2 Instance
# -----------------------------------------------------------------------------

resource "aws_instance" "k8s_node" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.k8s_public.id
  vpc_security_group_ids = [aws_security_group.k8s_node.id]
  key_name               = aws_key_pair.k8s_key.key_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true

    tags = {
      Name = "${var.hostname}-root"
    }
  }

  user_data = templatefile("${path.module}/templates/cloud-init-userdata.yaml", {
    hostname = var.hostname
  })

  tags = {
    Name = var.hostname
  }

  # Wait for instance to be ready
  provisioner "remote-exec" {
    inline = ["echo 'Instance is ready'"]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(replace(var.ssh_public_key_file, ".pub", ""))
      host        = self.public_ip
    }
  }
}

# -----------------------------------------------------------------------------
# Elastic IP (optional, for stable public IP)
# -----------------------------------------------------------------------------

resource "aws_eip" "k8s_node" {
  instance = aws_instance.k8s_node.id
  domain   = "vpc"

  tags = {
    Name = "${var.hostname}-eip"
  }
}

