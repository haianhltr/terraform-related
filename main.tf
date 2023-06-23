# deploy single virtual server in aws

provider "aws" { 
    region = "us-east-2"
}

# free AMI
# pass shell script to user data

resource "aws_instance" "example" {
  ami                    = "ami-0fb653ca2d3203ac1"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF


  tags = {
    Name = "terraform-example"
  }
}

resource "aws_security_group" "instance" {

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# define port number
variable "server_port" {
    description = "The port the server will use for HTTP requests"
    type = number
    default = 8080
}