# deploy single virtual server in aws

provider "aws" { 
    region = "us-east-2"
}

# free AMI
# pass shell script to user data

resource "aws_instance" "example" {
    ami = "ami-0c55b159cbfafe1f0" 
    instance_type = "t2.micro"


    user_data =  <<-EOF
        #!/bin/bash
        echo "Hellom World" > index.html
        nohup busybox httpd -f -p 8080 &
        EOF

    tags = {
        Name = "terraform-example"
    }
}

# create a security group to allow incoming/outgoing traffic from EC2 Instances

resource "aws_security_group" "instance" { 
    name = "terraform-example-instance"
    ingress {
        from_port =8080
        to_port = 8080 
        protocol = "tcp" 
        cidr_blocks = ["0.0.0.0/0"]
} 
}