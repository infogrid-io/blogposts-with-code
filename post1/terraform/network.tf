
# tensorflow VPC
resource "aws_vpc" "tensorflow" {
  cidr_block           = var.config.vpc_cidr_block
  enable_dns_support   = true /* Required for PrivateLink */
  enable_dns_hostnames = true /* Required for PrivateLink */
}

# Public Subnets
# Hack: route association (below) can't take a list of strings
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.tensorflow.id
  count             = length(var.config.subnet_cidrs_public)
  cidr_block        = var.config.subnet_cidrs_public[count.index]
  availability_zone = var.config.availability_zones[count.index]
}

# Private Subnets
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.tensorflow.id
  count             = length(var.config.subnet_cidrs_private)
  cidr_block        = var.config.subnet_cidrs_private[count.index]
  availability_zone = var.config.availability_zones[count.index]

}

# VPC Endpoint ECR
resource "aws_vpc_endpoint" "vpc_endpoint_ecr_api" {
  vpc_id              = aws_vpc.tensorflow.id
  service_name        = "com.amazonaws.${var.config.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.tensorflow.id]
  subnet_ids          = aws_subnet.private.*.id
  private_dns_enabled = true
}

# VPC Endpoint ECR
resource "aws_vpc_endpoint" "vpc_endpoint_ecr_dkr" {
  vpc_id              = aws_vpc.tensorflow.id
  service_name        = "com.amazonaws.${var.config.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.tensorflow.id]
  subnet_ids          = aws_subnet.private.*.id
  private_dns_enabled = true
}

# VPC Endpoint ECS 1
resource "aws_vpc_endpoint" "vpc_endpoint_ecs" {
  vpc_id              = aws_vpc.tensorflow.id
  service_name        = "com.amazonaws.${var.config.region}.ecs"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.tensorflow.id]
  subnet_ids          = aws_subnet.private.*.id
  private_dns_enabled = true
}

# VPC Endpoint ECS 2
resource "aws_vpc_endpoint" "vpc_endpoint_ecs-telemetry" {
  vpc_id              = aws_vpc.tensorflow.id
  service_name        = "com.amazonaws.${var.config.region}.ecs-telemetry"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.tensorflow.id]
  subnet_ids          = aws_subnet.private.*.id
  private_dns_enabled = true

}

# VPC Endpoint ECS 3
resource "aws_vpc_endpoint" "vpc_endpoint_ecs_agent" {
  vpc_id              = aws_vpc.tensorflow.id
  service_name        = "com.amazonaws.${var.config.region}.ecs-agent"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.tensorflow.id]
  subnet_ids          = aws_subnet.private.*.id
  private_dns_enabled = true
}

# VPC Endpoint S3
resource "aws_vpc_endpoint" "vpc_endpoint_s3" {
  vpc_id          = aws_vpc.tensorflow.id
  service_name    = "com.amazonaws.${var.config.region}.s3"
  route_table_ids = [aws_route_table.private.id]
}

# VPC Endpoint Logs
resource "aws_vpc_endpoint" "vpc_endpoint_logs" {
  vpc_id              = aws_vpc.tensorflow.id
  service_name        = "com.amazonaws.${var.config.region}.logs"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.tensorflow.id]
  subnet_ids          = aws_subnet.private.*.id
  private_dns_enabled = true
}

# Gateway
resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.tensorflow.id
}


# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.tensorflow.id
}

# Public Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tensorflow.id
}
# Route
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway.id
}

# Associate subnets to the public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public.*.id)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# Associate subnets to the private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private.*.id)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

# Associate the VPC with the route we're creating
resource "aws_main_route_table_association" "route_association" {
  vpc_id         = aws_vpc.tensorflow.id
  route_table_id = aws_route_table.public.id

}
