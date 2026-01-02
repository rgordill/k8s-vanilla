# =============================================================================
# AWS Provider Configuration
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
  default     = "eu-west-1a"
}

# =============================================================================
# EC2 Instance Configuration
# =============================================================================

variable "hostname" {
  description = "Hostname for the Kubernetes node"
  type        = string
  default     = "k8s-node"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"  # 2 vCPU, 8GB RAM
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Type of the root volume (gp3, gp2, io1)"
  type        = string
  default     = "gp3"
}

# =============================================================================
# AMI Configuration
# =============================================================================

variable "ami_id" {
  description = "AMI ID for the EC2 instance (leave empty to use latest Fedora)"
  type        = string
  default     = ""
}

variable "ami_owner" {
  description = "Owner ID for AMI lookup (Fedora Project)"
  type        = string
  default     = "125523088429"  # Fedora Project
}

variable "ami_name_pattern" {
  description = "Name pattern for AMI lookup"
  type        = string
  default     = "Fedora-Cloud-Base-*.x86_64-hvm-*-gp3-*"
}

# =============================================================================
# Authentication
# =============================================================================

variable "ssh_public_key_file" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_user" {
  description = "SSH user for the EC2 instance"
  type        = string
  default     = "fedora"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair to create"
  type        = string
  default     = "k8s-vanilla-key"
}

# =============================================================================
# Kubernetes Configuration
# =============================================================================

variable "pod_network_cidr" {
  description = "CIDR for Kubernetes pod network"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes service network"
  type        = string
  default     = "10.96.0.0/12"
}

