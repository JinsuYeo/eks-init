#########################################################################################################
## Create a VPC
#########################################################################################################
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "dev-ecom-vpc-main"
  }
}

#########################################################################################################
## Create Public & Private Subnet
#########################################################################################################
resource "aws_subnet" "ecom-sub-pub01" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/26"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "ecom-sub-pub01"
  }
}

resource "aws_subnet" "ecom-sub-pub02" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.64/26"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = {
    Name = "ecom-sub-pub02"
  }
}

resource "aws_subnet" "ecom-sub-pri01" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.128/26"
  availability_zone       = "ap-northeast-2a"
  tags = {
    Name = "ecom-sub-pri01"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "ecom-sub-pri02" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.192/26"
  availability_zone = "ap-northeast-2c"
  tags = {
      Name = "ecom-sub-pri02"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

#########################################################################################################
## Create Internet gateway & Nat gateway
#########################################################################################################
resource "aws_internet_gateway" "ecom-igw-main" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "ecom-igw-main"
  }
}

resource "aws_eip" "nat-eip-pub01" {
  domain = "vpc"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "nat-eip-pub02" {
  domain = "vpc"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_nat_gateway" "ecom-nat-pub01" {
  subnet_id     = aws_subnet.ecom-sub-pub01.id
  allocation_id = aws_eip.nat-eip-pub01.id
  tags = {
    Name = "ecom-nat-pub01"
  }
}

resource "aws_nat_gateway" "ecom-nat-pub02" {
  subnet_id     = aws_subnet.ecom-sub-pub02.id
  allocation_id = aws_eip.nat-eip-pub02.id
  tags = {
    Name = "ecom-nat-pub02"
  }
}

#########################################################################################################
## Create Route Table & Route
#########################################################################################################
resource "aws_route_table" "ecom-rtb-pub" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ecom-igw-main.id
  }
  tags = {
    Name = "ecom-rtb-pub"
  }
}

resource "aws_route_table_association" "public-rtb-assoc1" {
  route_table_id = aws_route_table.ecom-rtb-pub.id
  subnet_id      = aws_subnet.ecom-sub-pub01.id
}

resource "aws_route_table_association" "public-rtb-assoc2" {
  route_table_id = aws_route_table.ecom-rtb-pub.id
  subnet_id      = aws_subnet.ecom-sub-pub02.id
}


resource "aws_route_table" "ecom-rtb-pri01" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ecom-nat-pub01.id
  }
  tags = {
    Name = "ecom-rtb-pri01"
  }
}

resource "aws_route_table" "ecom-rtb-pri02" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ecom-nat-pub02.id
  }
  tags = {
    Name = "ecom-rtb-pri02"
  }
}

resource "aws_route_table_association" "private-rtb-assoc1" {
  route_table_id = aws_route_table.ecom-rtb-pri01.id
  subnet_id      = aws_subnet.ecom-sub-pri01.id
}

resource "aws_route_table_association" "private-rtb-assoc2" {
  route_table_id = aws_route_table.ecom-rtb-pri02.id
  subnet_id      = aws_subnet.ecom-sub-pri02.id
}

#########################################################################################################
## Create Security Group
#########################################################################################################
resource "aws_security_group" "ecom-sg-cli" {
  name        = "ecom-sg-cli"
  description = "ecom-sg-cli"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "allow-https" {
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.ecom-sg-cli.id
  to_port           = 443
  type              = "ingress"
  description       = "https"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow-all-ports-egress" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ecom-sg-cli.id
  to_port           = 0
  type              = "egress"
  description       = "all ports"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "ecom-sg-ssmendpoint" {
  name        = "ecom-sg-ssmendpoint"
  description = "ecom-sg-ssmendpoint"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "allow-https-endpoint" {
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.ecom-sg-ssmendpoint.id
  to_port           = 443
  type              = "ingress"
  description       = "https"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow-https-egress" {
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecom-sg-ssmendpoint.id
  to_port                  = 443
  type                     = "egress"
  description              = "https egress"
  source_security_group_id = aws_security_group.ecom-sg-cli.id # 허용할 특정 보안 그룹 ID
} 

#########################################################################################################
## Create VPC Endpoint
#########################################################################################################
resource "aws_vpc_endpoint" "ecom-endpoint-ec2messages" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.ap-northeast-2.ec2messages"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.ecom-sg-ssmendpoint.id,
  ]

  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.ecom-sub-pri01.id, aws_subnet.ecom-sub-pri02.id
  ]
}

resource "aws_vpc_endpoint" "ecom-endpoint-ssmmessages" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.ap-northeast-2.ssmmessages"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.ecom-sg-ssmendpoint.id,
  ]

  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.ecom-sub-pri01.id, aws_subnet.ecom-sub-pri02.id
  ]
}

resource "aws_vpc_endpoint" "ecom-endpoint-ssm" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.ap-northeast-2.ssm"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.ecom-sg-ssmendpoint.id,
  ]

  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.ecom-sub-pri01.id, aws_subnet.ecom-sub-pri02.id
  ]
}