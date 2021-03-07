# Task Definition
resource "aws_ecs_task_definition" "dummy" {
  container_definitions = templatefile("container_definitions/dummy_service.json", {
    dummy_image        = var.config.dummy_image
    ecs_security_group = aws_security_group.tensorflow.arn
    subnets            = join(",", aws_subnet.private.*.id)
    awslogs_group      = var.config.dummy_awslogs_group
    region             = var.config.region
    log_level          = var.config.log_level
    memoryReservation  = var.config.memoryReservation
    model_name         = var.config.model_name
    tensorflow_port    = var.config.tensorflow_port
    tensorflow_dns     = aws_lb.tensorflow-lb.dns_name
  })

  family                   = "dummy"
  task_role_arn            = aws_iam_role.tensorflow_task.arn
  execution_role_arn       = aws_iam_role.tensorflow_task.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.config.cpu
  memory                   = var.config.memory
}

# Service
resource "aws_ecs_service" "dummy" {
  name            = "dummy"
  cluster         = aws_ecs_cluster.tensorflow.id
  task_definition = aws_ecs_task_definition.dummy.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets          = aws_subnet.private.*.id
    security_groups  = [aws_security_group.tensorflow.id]
    assign_public_ip = false
  }
}

# Cloudwatch group
resource "aws_cloudwatch_log_group" "dummy" {
  name              = var.config.dummy_awslogs_group
  retention_in_days = var.config.log_retention_in_days
}

# Autoscaling Target
resource "aws_appautoscaling_target" "dummy_autoscaling_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.tensorflow.name}/${aws_ecs_service.dummy.name}"
  role_arn           = aws_iam_role.tensorflow_task.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

}

# Autoscaling Policy
resource "aws_appautoscaling_policy" "dummy_autoscaling_policy" {
  name               = "dummy-autoscaling-policy-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dummy_autoscaling_target.id
  scalable_dimension = aws_appautoscaling_target.dummy_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dummy_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
