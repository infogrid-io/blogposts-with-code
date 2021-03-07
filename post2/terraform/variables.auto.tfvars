### ANALYTICS

config = {
  tensorflow_awslogs_group = "/ecs/tensorflow_service",
  dummy_awslogs_group      = "/ecs/dummy_service",
  log_level                = "INFO",
  log_retention_in_days    = 30

  model_name                    = "empty_model",
  model_bucket_name             = "tensorflow-test-model-1234",
  cpu                           = 512,
  memory                        = 1024,
  memoryReservation             = 1024,
  model_version_polling_seconds = 600,
  tensorflow_image              = "091490437432.dkr.ecr.eu-west-1.amazonaws.com/tensorflow_inference:2.3.0-cpu-py37-ubuntu18.04" #"${path to tensorflow/serving:2.4.0 stored in your own ECR}$"
  dummy_image                   = "091490437432.dkr.ecr.eu-west-1.amazonaws.com/analytics:aidans_branch.v1"                      #"${path to dummy_service image stored in your own ECR}$"
  region                        = "eu-west-1"
  tensorflow_port               = 8888

  vpc_cidr_block       = "10.0.0.0/16"
  availability_zones   = ["eu-west-1a", "eu-west-1b"]
  subnet_cidrs_private = ["10.0.7.0/24", "10.0.8.0/24"]
}
