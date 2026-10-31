terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}


# Network


module "network" {
  source = "git::https://github.com/leyisco101/cob-modules.git//network?ref=v1.0.0"

  project     = var.project
  environment = var.environment

  vpc_cidr = "10.20.0.0/16"

  availability_zones = [
    "us-east-1a",
    "us-east-1b"
  ]

  public_subnet_cidrs = [
    "10.20.1.0/24",
    "10.20.2.0/24"
  ]

  private_subnet_cidrs = [
    "10.20.11.0/24",
    "10.20.12.0/24"
  ]

  tags = {
    Owner = "Platform-Engineering"
  }
}


# Storage


module "storage" {
  source = "git::https://github.com/leyisco101/cob-modules.git//storage?ref=v1.0.0"

  project     = var.project
  environment = var.environment

  bucket_purpose = "application-data"

  enable_versioning         = true
  lifecycle_expiration_days = 90

  tags = {
    Owner = "Platform-Engineering"
  }
}


# IAM

module "iam" {
  source = "git::https://github.com/leyisco101/cob-modules.git//iam?ref=v1.0.0"

  project     = var.project
  environment = var.environment

  bucket_arn = module.storage.bucket_arn

  tags = {
    Owner = "Platform-Engineering"
  }
}




# ECS


module "ecs" {
  source = "git::https://github.com/leyisco101/cob-modules.git//compute-ecs?ref=v1.0.0"

  project     = var.project
  environment = var.environment

  vpc_id = module.network.vpc_id

  private_subnet_ids = module.network.private_subnet_ids

  task_role_arn = module.iam.workload_role_arn

  container_image = "nginx:latest"
  container_port  = 80

  cpu           = 256
  memory        = 512
  desired_count = 1

  tags = {
    Owner = "Platform-Engineering"
  }
}


# Database


module "database" {
  source = "git::https://github.com/leyisco101/cob-modules.git//database?ref=v1.0.0"

  project     = var.project
  environment = var.environment

  vpc_id = module.network.vpc_id

  private_subnet_ids = module.network.private_subnet_ids

  allowed_security_group_id = module.ecs.ecs_security_group_id

  database_name     = "appdb"
  database_username = "cobadmin"
  database_password = var.database_password

  instance_class    = "db.t3.micro"
  allocated_storage = 20

  backup_retention_days = 1

  tags = {
    Owner = "Platform-Engineering"
  }
}

module "ec2" {
  source = "git::https://github.com/leyisco101/cob-modules.git//compute-ec2?ref=v1.0.0"

  project     = var.project
  environment = var.environment

  vpc_id = module.network.vpc_id

  private_subnet_ids = module.network.private_subnet_ids

  instance_type    = "t3.micro"
  root_volume_size = 8

  tags = {
    Owner = "Platform-Engineering"
  }
}


module "data_platform" {
  source = "git::https://github.com/leyisco101/cob-modules.git//data-platform?ref=v1.0.0"

  project     = var.project
  environment = var.environment

  data_bucket_name = module.storage.bucket_name
  data_prefix      = var.data_prefix

  athena_results_expiration_days = var.athena_results_expiration_days

  tags = {
    Owner = "Platform-Engineering"
  }
}