terraform {
  backend "s3" {
    bucket = "protalento-s3-terraform-state"
    key    = "protalento/state."
    region = "us-east-1"
  }
}

// NETWORK
resource "aws_ecs_cluster" "protalento_cluster" {
  name = "protalento-cluster"
}

resource "aws_vpc" "protalento_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "protalento"
  }
}

resource "aws_subnet" "protalento_subnet" {
  vpc_id     = aws_vpc.protalento_vpc.id
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "protalento"
  }
}

// IMAGE

resource "aws_ecr_repository" "protalentp_ecr" {
  name                 = "protalento-hello-world"
  image_tag_mutability = "MUTABLE"
}

// SERVICE
resource "aws_security_group" "allow_tls" {
  name        = "protalento-allow-tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.protalento_vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.protalento_vpc.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_lb" "protalento_lb" {
  name               = "protalento_cluster"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_tls.id]
  subnets            = [for subnet in aws_subnet.protalento_subnet : subnet.id]

  enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "protalento_tg" {
  name     = "protalento-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.protalento_vpc.id
}

resource "aws_ecs_task_definition" "protalento_td" {
  family                   = "protalento-hello-world-td"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  container_definitions    = <<TASK_DEFINITION
[
  {
    "name": "protalento-hello-world",
    "image": ${aws_ecr_repository.protalentp_ecr.repository_url}/${var.image_name},
    "cpu": 256,
    "memory": 512,
    "essential": true
  }
]
TASK_DEFINITION
}

resource "aws_ecs_service" "protalento_service" {
  name            = "hello-world-service"
  cluster         = aws_ecs_cluster.protalento_cluster.id
  task_definition = aws_ecs_task_definition.protalento_td
  desired_count   = 1
  launch_type = "FARGATE"


  load_balancer {
    target_group_arn = aws_lb_target_group.protalento_tg.arn
    container_name   = "protalento-hello-world"
    container_port   = 8080
  }
}

//VARIABLES

variable "image_name" {
  type = string
}