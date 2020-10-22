variable "region" {
  default = "us-east-1"
}
variable "az1" {
  default = "us-east-1a"
}
variable "az2" {
  default = "us-east-1b"
}
variable "az3" {
  default = "us-east-1c"
}


provider "aws" {
    profile = "dev1"
    region = var.region
}

resource "aws_vpc" "vpc-1" {
    cidr_block              = "10.0.0.0/16"
    enable_dns_hostnames    = true
    enable_dns_support      = true
    assign_generated_ipv6_cidr_block = false
}
resource "aws_subnet" "subnet-1" {
    cidr_block              = "10.0.1.0/24"
    vpc_id                  = aws_vpc.vpc-1.id
    availability_zone       = var.az1
    map_public_ip_on_launch = true
    tags = {
        Name = "csye6225-subnet-1"
    }
}

resource "aws_subnet" "subnet-2" {
    cidr_block              = "10.0.2.0/24"
    vpc_id                  = aws_vpc.vpc-1.id
    availability_zone       = var.az2
    map_public_ip_on_launch = true
    tags = {
        Name = "csye6225-subnet-2"
    }
}

resource "aws_subnet" "subnet-3" {
    cidr_block              = "10.0.3.0/24"
    vpc_id                  = aws_vpc.vpc-1.id
    availability_zone       = var.az3
    map_public_ip_on_launch = true
    tags = {
        Name = "csye6225-subnet-3"
    }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc-1.id
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.vpc-1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}