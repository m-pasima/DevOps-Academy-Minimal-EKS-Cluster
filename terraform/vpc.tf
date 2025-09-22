resource "aws_vpc" "this" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = {
    a = data.aws_availability_zones.available.names[0]
    b = data.aws_availability_zones.available.names[1]
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.key == "a" ? "10.10.1.0/24" : "10.10.2.0/24"
  availability_zone       = each.value
  map_public_ip_on_launch = true

  # IMPORTANT TAGS:
  # - elb tag marks these as "public" for classic/NLB/ALB controller
  # - cluster tag allows the AWS LB Controller / k8s to discover usable subnets
  tags = {
    Name                                                = "${var.project_name}-public-${each.key}"
    "kubernetes.io/role/elb"                            = "1"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "default_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
