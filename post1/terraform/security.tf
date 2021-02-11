# Security Group
resource "aws_security_group" "tensorflow" {
  name   = "tensorflow"
  vpc_id = aws_vpc.tensorflow.id

  # Tensorflow Serving Service operates on these two ports
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "TCP"
    cidr_blocks = [aws_vpc.tensorflow.cidr_block]
  }
  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "TCP"
    cidr_blocks = [aws_vpc.tensorflow.cidr_block]
  }
  # Ingress to the ALB from the user's local machine
  ingress {
    from_port   = var.config.tensorflow_port
    to_port     = var.config.tensorflow_port
    protocol    = "TCP"
    cidr_blocks = ["${local.ip}/32"]
  }
  # Open egress permitted
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Ingress from ECR
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = [aws_vpc.tensorflow.cidr_block]
  }
}

# Local IP address to whitelist access to the ALB
data "http" "my_public_ip" {
  url = "https://ifconfig.me"
}
locals {
  ip = data.http.my_public_ip.body
}

# IAM role for task role and task execution
data "aws_iam_policy_document" "tensorflow" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "tensorflow_task" {
  name               = "tensorflow_task_tf"
  assume_role_policy = data.aws_iam_policy_document.tensorflow.json
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.tensorflow_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "attach_task_execution_policy" {
  role       = aws_iam_role.tensorflow_task.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "attach_ecs_policy" {
  role       = aws_iam_role.tensorflow_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_iam_role_policy_attachment" "attach_cloudWatch_policy" {
  role       = aws_iam_role.tensorflow_task.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "attach_autoscaling_full_policy" {
  role       = aws_iam_role.tensorflow_task.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

resource "aws_iam_role_policy_attachment" "attach_ecr_policy" {
  role       = aws_iam_role.tensorflow_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}
