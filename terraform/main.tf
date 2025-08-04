# terraform/main.tf

# Configure the Terraform AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Set the provider to use the region from our variables file
provider "aws" {
  region = var.aws_region
}

# Get the list of Availability Zones in the current region
# This makes our code reusable in any region
data "aws_availability_zones" "available" {}

# 1. NETWORKING
# -----------------------------------------------------------------------------
# The VPC: our own private corner of the AWS cloud
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Public Subnets: Parts of our VPC that can reach the internet
# We create two for High Availability across different Availability Zones (AZs)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # Instances in this subnet get a public IP
  tags = {
    Name = "${var.project_name}-public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-public-subnet-b"
  }
}

# An Internet Gateway to allow communication between our VPC and the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# A Route Table to define rules for traffic routing
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0" # Traffic to anywhere
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate our public subnets with the public route table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# 2. SECURITY
# -----------------------------------------------------------------------------
# A Security Group for our Application Load Balancer (ALB)
# It allows web traffic from the internet (port 80)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# A Security Group for our EC2 application instances
# It only allows traffic from our Load Balancer
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allow traffic from the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # IMPORTANT: Only accepts traffic from the ALB SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. CONTAINER REPOSITORY
# -----------------------------------------------------------------------------
# The ECR repository where our Docker images will be stored
resource "aws_ecr_repository" "app" {
  name = var.project_name
}

# terraform/main.tf (APPEND THIS CODE)

# 4. S3 BUCKET FOR ARTIFACTS
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.project_name}-codepipeline-artifacts-${random_id.bucket_id.hex}"
  # Bucket names must be globally unique, so we add a random suffix
}

resource "random_id" "bucket_id" {
  byte_length = 8
}

# 5. APPLICATION LOAD BALANCER (ALB)
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# 6. AUTO SCALING INFRASTRUCTURE
# -----------------------------------------------------------------------------
# Find the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# This is the blueprint for our EC2 instances
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_instance_profile.arn
  }
  vpc_security_group_ids = [aws_security_group.app.id]

  # This script runs when the instance first starts.
  # It installs the CodeDeploy agent and Docker.
  user_data = base64encode(<<-EOF
          #!/bin/bash
          sudo yum update -y
          sudo yum install -y ruby wget docker
          sudo service docker start
          sudo usermod -a -G docker ec2-user
          cd /home/ec2-user
          wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
          chmod +x ./install
          sudo ./install auto
          sudo service codedeploy-agent start
          EOF
  )
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.project_name
    }
  }
}

# This group manages our EC2 instances, ensuring we have 2 running
resource "aws_autoscaling_group" "main" {
  name                = "${var.project_name}-asg"
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.main.arn]
  # This tag is how CodeDeploy will find the instances
  tag {
    key                 = "Name"
    value               = var.project_name
    propagate_at_launch = true
  }
}

# 7. CODEDEPLOY RESOURCES
# -----------------------------------------------------------------------------
resource "aws_codedeploy_app" "main" {
  compute_platform = "Server"
  name             = var.project_name
}

resource "aws_codedeploy_deployment_group" "main" {
  app_name              = aws_codedeploy_app.main.name
  deployment_group_name = "${var.project_name}-dg"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  autoscaling_groups = [aws_autoscaling_group.main.name]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.main.name
    }
  }
}