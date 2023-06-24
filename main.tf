# deploy single virtual server in aws
provider "aws" { 
    region = "us-east-2"
}

# pass shell script to user data
# create launch configuration
resource "aws_launch_configuration" "example" {
  image_id        = "ami-0fb653ca2d3203ac1"
  instance_type          = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  # Required when using a launch configuration with an auto scaling group. 
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html 
  lifecycle {
    create_before_destroy = true 
  }
}

resource "aws_autoscaling_group" "example" {
    launch_configuration =aws_launch_configuration.example.name
    vpc_zone_identifier = data.aws_subnets.default.ids

    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"


    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch = true
    }
}

resource "aws_security_group" "instance" {
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#use aws_vpc data source to look up the data default for VPC
data "aws_vpc" "default" {
    default = true
}

#get id of vpc
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


# create application load balancer 
resource "aws_lb" "example" {
    name = "terraform-asg-example"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.alb.id]
}

# define a listener for the ALB
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn 
    port = 80
    protocol = "HTTP"
    # By default, return a simple 404 page
    default_action {
        type = "fixed-response"
        fixed_response {
          content_type = "text/plain"
          message_body = "404: page not found"
          status_code  = 404
} 
}
}



# define port number
variable "server_port" {
    description = "The port the server will use for HTTP requests"
    type = number
    default = 8080
}


#provide the IP address as an output variable:
output "alb_dns_name" {
    value       = aws_lb.example.dns_name
    description = "The domain name of the load balancer"
}


#create security group for ALB
resource "aws_security_group" "alb" { 
    name = "terraform-example-alb"
    # Allow inbound HTTP requests
    ingress {
        from_port =80
        to_port = 80
        protocol = "tcp" 
        cidr_blocks = ["0.0.0.0/0"]
    }
    # Allow all outbound requests

    egress {
        from_port =0
        to_port = 0
        protocol = "-1" 
        cidr_blocks = ["0.0.0.0/0"]
}
}

# target group for ASG
# check instances by sending requests periodically

resource "aws_lb_target_group" "asg" {
  name = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


# create listener rules
resource "aws_lb_listener_rule" "asg" { 
    listener_arn = aws_lb_listener.http.arn 
    priority = 100
      condition {
        path_pattern {
          values = ["*"]
        }
}
      action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
} 
}