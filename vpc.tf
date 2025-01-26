resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  instance_tenancy = "default" # Makes all instances on the same host
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment}-vpc"
    Environment = var.environment
  }
}

#Create Subnets
resource "aws_subnet" "public-subnet" {
  vpc_id            = aws_vpc.main.id
  count             = length(local.availability_zones)
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = element(local.availability_zones, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "Public subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private-subnet" {
  vpc_id            = aws_vpc.main.id
  count             = length(local.availability_zones)
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 3)
  availability_zone = element(local.availability_zones, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "Private subnet ${count.index + 1}"
  }
}

#IGW
resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
    Environment = var.environment
  }
  
}

# Route Table from IGW src 
resource "aws_route_table" "route-table-from-igw-src" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block="0.0.0.0/0" # Meaning all traffics coming from gateway can be routed through this
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Routing Association 
resource "aws_route_table_association" "public-subnet-assoc" {
  count = length(var.public_subnets_cidr)
  subnet_id = element(aws_subnet.public-subnet[*].id, count.index)
  route_table_id = aws_route_table.route-table-from-igw-src.id
}

# Nat-GW Setup -  1 Nat-GW for Private subnets in Multiple AZs
resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id=aws_eip.eip.id
  subnet_id = element(aws_subnet.public-subnet[*].id, 0)
  depends_on = [ aws_internet_gateway.igw ]
}

resource "aws_route_table" "route-table-from-nat-gw-src" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }

  tags = {
    Name = "${var.environment}-nat-gw"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private-subnet-assoc" {
  count = length(var.private_subnets_cidr)
  subnet_id = element(aws_subnet.private-subnet[*].id, count.index)
  route_table_id = aws_route_table.route-table-from-nat-gw-src.id
}

# Nat-GW Setup - Multiple Nat-GW for Private subnets in Multiple AZs
# resource "aws_eip" "eip" {
#   count = length(var.private_subnets_cidr)  # Create one EIP for each private subnet

#   domain = "vpc"
# }

# resource "aws_nat_gateway" "nat-gw" {
#   count           = length(var.private_subnets_cidr)  # Create a NAT Gateway per private subnet
#   allocation_id   = element(aws_eip.eip[*].id, count.index)  # Dynamically select EIP based on the count index
#   subnet_id       = element(aws_subnet.public-subnet[*].id, count.index)  # Select correct public subnet based on AZ index
#   depends_on       = [aws_internet_gateway.igw]
# }

# resource "aws_route_table" "route-table-from-nat-gw-src" {
#   count   = length(var.private_subnets_cidr)
#   vpc_id  = aws_vpc.main.id

#   route {
#     cidr_block      = "0.0.0.0/0"  # Route internet traffic
#     nat_gateway_id  = element(aws_nat_gateway.nat-gw[*].id, count.index)  # Use correct NAT GW
#   }

#   tags = {
#     Name        = "${var.environment}-nat-gw-route-table-${count.index}"
#     Environment = var.environment
#   }
# }

# resource "aws_route_table_association" "private-subnet-assoc" {
#   count = length(var.private_subnets_cidr)

#   subnet_id      = element(aws_subnet.private-subnet[*].id, count.index)  # Associate with correct Private Subnet
#   route_table_id = aws_route_table.route-table-from-nat-gw-src[count.index].id  # Associate with correct Route Table
# }