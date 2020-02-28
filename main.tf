# Specify the provider and access details
provider "aws" {
  region = var.aws_region
}

# Create a VPC to launch our instances into
resource "aws_vpc" "terraform1" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "terraform1" {
  vpc_id = aws_vpc.terraform1.id
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.terraform1.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.terraform1.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "tf1-sub1a" {
  vpc_id                  = aws_vpc.terraform1.id
  cidr_block              = "10.0.1.0/26"
  availability_zone     = var.aws_az1
  map_public_ip_on_launch = true
}

resource "aws_subnet" "tf1-sub1b" {
  vpc_id                  = aws_vpc.terraform1.id
  cidr_block              = "10.0.1.64/26"
  availability_zone     = var.aws_az2
  map_public_ip_on_launch = true
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "elb" {
  name        = "terraform_example_elb"
  description = "Used in the terraform"
  vpc_id      = aws_vpc.terraform1.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our terraform1 security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "terraform1" {
  name        = "terraform_example"
  description = "Used in the terraform"
  vpc_id      = aws_vpc.terraform1.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "web" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  subnets         = [aws_subnet.tf1-sub1a.id, aws_subnet.tf1-sub1b.id]
  security_groups = [aws_security_group.elb.id]
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener_rule" "web" {
  listener_arn = aws_lb_listener.web.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = ["/web/*"]
    }
  }
}

resource "aws_lb_listener_rule" "app" {
  listener_arn = aws_lb_listener.web.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = ["/app/*"]
    }
  }
}

resource "aws_lb_target_group" "app" {
  name     = "tf-example-lb-tg-app"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform1.id
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.web.id
  port             = 80
}

resource "aws_lb_target_group" "web" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform1.id
}

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web.id
  port             = 80
}

resource "aws_key_pair" "auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "web" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ec2-user"
    host = self.public_ip
    # The connection will use the local SSH agent for authentication.
    agent = false

    type = "ssh"
    private_key = file(var.private_key_path)
  }

  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region
  # we specified
  ami = lookup(var.aws_amis, var.aws_region)

  # The name of our SSH keypair we created above.
  key_name = aws_key_pair.auth.id

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = [aws_security_group.terraform1.id]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = aws_subnet.tf1-sub1a.id
  
  # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install httpd",
      "sudo service httpd start",
    ]
  }
}
