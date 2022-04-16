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
  cidr_block = "10.0.0.0/17"
  availability_zone = "us-east-1a"

  tags = {
    Name = "protalento-a"
  }
}

resource "aws_subnet" "protalento_subnet_2" {
  vpc_id     = aws_vpc.protalento_vpc.id
  cidr_block = "10.0.128.0/17"
  availability_zone = "us-east-1b"

  tags = {
    Name = "protalento-b"
  }
}

resource "aws_internet_gateway" "protalento_gw" {
  vpc_id = aws_vpc.protalento_vpc.id

  tags = {
    Name = "protalento-ig"
  }
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.protalento_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.protalento_gw.id
  }

  tags = {
    Name = "protalento"
  }
}

resource "aws_main_route_table_association" "association" {
  vpc_id     = aws_vpc.protalento_vpc.id
  route_table_id = aws_route_table.route.id
}

resource "aws_security_group" "allow_tls" {
  name        = "protalento-allow-tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.protalento_vpc.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
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

// IMAGE

resource "aws_ecr_repository" "protalento_ecr" {
  name                 = "protalento-hello-world"
  image_tag_mutability = "MUTABLE"
}

// SERVICE

resource "aws_ecs_task_definition" "protalento_td" {
  family                   = "protalento-hello-world-td"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = "arn:aws:iam::${var.account_id}:role/ProtalentoTaskExecutionRole"
  container_definitions    = <<TASK_DEFINITION
[
  {
    "name": "protalento-hello-world",
    "image": "${var.account_id}.dkr.ecr.us-east-1.amazonaws.com/protalento-hello-world:first-push",
    "cpu": 256,
    "memory": 512,
    "essential": true,
    "portMappings": [{"containerPort": 8080}],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "/ecs/hello-world-service",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "ecs"
        }
    }
  }
]
TASK_DEFINITION
}

resource "aws_ecs_service" "protalento_service" {
  name                 = "hello-world-service"
  cluster              = aws_ecs_cluster.protalento_cluster.id
  task_definition      = aws_ecs_task_definition.protalento_td.id
  desired_count        = 1
  launch_type          = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.protalento_subnet.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.protalento_tg.arn
    container_name   = "protalento-hello-world"
    container_port   = 8080
  }
}


// CLOUDWATCH
resource "aws_cloudwatch_log_group" "service_cw" {
  name = "/ecs/hello-world-service"
}

// VARIABLE

variable "account_id" {
  type = string
}