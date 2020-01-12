provider "aws" {
  region = var.region
  access_key = var.ak
  secret_key = var.sk
}

module "vpc" {
  source = "./terraform-aws-vpc"
  name = "HC-TEST"
  cidr = "${lookup(var.cidr_ab, var.environment)}.0.0/16"
  private_subnets = local.private_subnets
  public_subnets = local.public_subnets
  azs = local.availability_zones
  enable_nat_gateway = true
}

data "aws_ami" "ecs_ami" {
  most_recent = true
  owners = [
    "amazon"]

  filter {
    name = "name"
    values = [
      "amzn-ami-*-amazon-ecs-optimized"]
  }
}

module "app_ecs_cluster" {
  source = "./terraform-aws-ecs-cluster"

  name = "app"
  environment = var.environment

  image_id = data.aws_ami.ecs_ami.image_id
  instance_type = "t2.micro"

  subnet_ids = module.vpc.private_subnets
  desired_capacity = 3
  max_size = 3
  min_size = 3
  vpc_id = module.vpc.vpc_id
}

module "app_ecs_security" {

  source = "./terraform-aws-security"
  app_port = "80"
  application_name = var.environment
  clustername = module.app_ecs_cluster.ecs_cluster_name
  environment = var.environment
  region = var.region
  subnets = module.vpc.public_subnets
  vpc_id = module.vpc.vpc_id
}

module "app_ecs_service" {
  source = "./terraform-aws-ecs-app"
  name = "nginx"
  environment = var.environment
  container_image = "nginx"
  container_port = "80"
  ecs_cluster = {
    arn = module.app_ecs_cluster.ecs_cluster_arn
    name = module.app_ecs_cluster.ecs_cluster_name
  }
  ecs_vpc_id = module.vpc.vpc_id
  ecs_subnet_ids = module.vpc.private_subnets
  tasks_desired_count = 2
  tasks_minimum_healthy_percent = 50
  tasks_maximum_percent = 200
  associate_alb = true
  alb_security_group = module.app_ecs_security.sg_lb
  lb_target_group = module.app_ecs_security.tg
}


