# tensorflow VPC
resource "aws_vpc" "tensorflow" {
  cidr_block           = var.config.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
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

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.tensorflow.id
}

# Associate subnets to the private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private.*.id)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}
