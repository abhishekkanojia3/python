provider "aws" {
  version = "~> 3.0"
  region  = "ap-south-1"
}

terraform{
  backend "s3"{
    bucket = "cjolopo"
    key    = "cjolopo/devops/state.tf"
    region = "ap-south-1"
}
}


# Create a VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.0.0/25"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "tf-example1"
  }
}
resource "aws_subnet" "my_subnet2" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.0.128/25"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "tf-example2"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "IG"
  }
}
resource "aws_route_table" "practice" {
  vpc_id = aws_vpc.example.id

  route = []
  
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.practice.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.my_subnet2.id
  route_table_id = aws_route_table.practice.id
}
resource "aws_route" "route_entry" {
  route_table_id            = aws_route_table.practice.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.gw.id
}

resource "aws_security_group" "allow_lb" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.example.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 21
    to_port          = 8051
    protocol         = "tcp"
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
    Name = "allow_lb"
  }
}
data "template_file" "user_data" {
  template = file("/scripts/web.sh")
}
#Create a ec2
resource "aws_instance" "web" {
  ami           = "ami-026f33d38b6410e30"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.my_subnet.id  
  user_data     = data.template_file.user_data.rendered
  vpc_security_group_ids = [aws_security_group.allow_lb.id]
  key_name = "terraform"
  tags = {
    Name = "HelloWorld"
  }
}
resource "aws_instance" "web1" {
  ami= "ami-026f33d38b6410e30"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.my_subnet2.id
  user_data = data.template_file.user_data.rendered
  vpc_security_group_ids = [aws_security_group.allow_lb.id]
  key_name = "terraform"
  tags = {
    Name = "HelloWorld"
  }
}
resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.example.id
}
resource "aws_lb_target_group_attachment" "testing" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id        = aws_instance.web1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "testing1" {
target_group_arn = aws_lb_target_group.test.arn
target_id= aws_instance.web.id
port= 80
}
resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_lb.id]
  subnet_mapping {
    subnet_id        = aws_subnet.my_subnet.id
    
  }

  subnet_mapping {
    subnet_id        = aws_subnet.my_subnet2.id
  }

 

  tags = {
    Environment = "production"
  }
}
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}
