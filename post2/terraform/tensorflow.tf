# Cloud provider
provider "aws" {
  region = var.config.region
}

# Keep the terraform backend on the local machine
terraform {
  backend "local" {}
}

# We pack everything into one variable dictionary
variable "config" {}

# ECS Cluster
resource "aws_ecs_cluster" "tensorflow" {
  name = "tensorflow"
}

# Task Definition
resource "aws_ecs_task_definition" "tensorflow" {
  container_definitions = templatefile("container_definitions/tensorflow_service.json", {
    tensorflow_image              = var.config.tensorflow_image
    ecs_security_group            = aws_security_group.tensorflow.arn
    subnets                       = join(",", aws_subnet.private.*.id)
    awslogs_group                 = var.config.tensorflow_awslogs_group
    region                        = var.config.region
    log_level                     = var.config.log_level
    memoryReservation             = var.config.memoryReservation
    model_name                    = var.config.model_name
    model_storage_s3_bucket       = aws_s3_bucket.tensorflow.id
    model_version_polling_seconds = var.config.model_version_polling_seconds
    cluster_name                  = "tensorflow"
  })

  family                   = "tensorflow"
  task_role_arn            = aws_iam_role.tensorflow_task.arn
  execution_role_arn       = aws_iam_role.tensorflow_task.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.config.cpu
  memory                   = var.config.memory
}


# Service
resource "aws_ecs_service" "tensorflow" {
  name            = "tensorflow"
  cluster         = aws_ecs_cluster.tensorflow.id
  task_definition = aws_ecs_task_definition.tensorflow.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  depends_on      = [aws_ecs_task_definition.tensorflow]

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets          = aws_subnet.private.*.id
    security_groups  = [aws_security_group.tensorflow.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tensorflow.arn
    container_name   = "tensorflow"
    container_port   = 8501
  }
}

# Cloudwatch group
resource "aws_cloudwatch_log_group" "tensorflow" {
  name              = var.config.tensorflow_awslogs_group
  retention_in_days = var.config.log_retention_in_days
}

# Application Load Balancer
resource "aws_lb" "tensorflow-lb" {
  name               = "tensorflow-lb"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.tensorflow.id]
  subnets            = aws_subnet.private.*.id
  enable_http2       = true
}

# Target Group
resource "aws_lb_target_group" "tensorflow" {
  name        = "tensorflow-target-group"
  port        = 8501
  protocol    = "HTTP"
  vpc_id      = aws_vpc.tensorflow.id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    port     = 8501
    path     = "/v1/models/${var.config.model_name}"
  }

  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  depends_on = [aws_lb.tensorflow-lb]

}

# Load Balancer Listener
resource "aws_lb_listener" "tensorflow" {
  load_balancer_arn = aws_lb.tensorflow-lb.arn
  port              = var.config.tensorflow_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tensorflow.arn
    type             = "forward"
  }
}

# Autoscaling Target
resource "aws_appautoscaling_target" "tensorflow" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.tensorflow.name}/${aws_ecs_service.tensorflow.name}"
  role_arn           = aws_iam_role.tensorflow_task.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Autoscaling Policy
resource "aws_appautoscaling_policy" "tensorflow" {
  name               = "tensorflow-autoscaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.tensorflow.id
  scalable_dimension = aws_appautoscaling_target.tensorflow.scalable_dimension
  service_namespace  = aws_appautoscaling_target.tensorflow.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# s3 Bucket to store ml_inference models
resource "aws_s3_bucket" "tensorflow" {
  bucket        = var.config.model_bucket_name
  acl           = "private"
  force_destroy = false
}

# VPC Access Point s3 for Analytics ml_inference service
resource "aws_s3_access_point" "tensorflow" {
  bucket = aws_s3_bucket.tensorflow.id
  name   = "tensorflow"

  vpc_configuration {
    vpc_id = aws_vpc.tensorflow.id
  }
}

# Blocking all public access to s3 bucket
resource "aws_s3_bucket_public_access_block" "tensorflow" {
  bucket                  = aws_s3_bucket.tensorflow.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
