# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

## Inspired from various readed exemples :
# VPS module : https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
# EKS module : https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
# ESK How to : https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
## :-)

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.6.2"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  cluster_name = "ecf-eks-cluster"
}

###
####
# Create VPC and subnets
####
###
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  # version = "5.0.0"

  name = "ecf-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

###
####
# Create the cluster
####
###
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  # version = "~> 19.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.27"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_ARM_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM
  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t4g.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }

    two = {
      name = "node-group-2"

      instance_types = ["t4g.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }  
}