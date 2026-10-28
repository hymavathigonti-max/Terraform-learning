# 1. VPC AND SUBNETS

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "Web-Server-VPC"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "SUBNET-A"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "SUBNET-B"
  }
}

# Data source to pull the latest Ubuntu 24.04 LTS AMI ID

data "aws_ami" "ubuntu_latest" {
  most_recent = true
  owners      = ["099720109477"] # Canonical owner ID for official Ubuntu AMIs
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}


# 3. INTERNET GATEWAY & ROUTE TABLES

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}


# SECURITY GROUPS

resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

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

resource "aws_security_group" "server_sg" {
  name        = "server-security-group"
  description = "Allow HTTP from ALB only"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. SERVERS (UBUNTU WITH UPDATED LIFECYCLE)

resource "aws_instance" "server_a" {
  ami                    = data.aws_ami.ubuntu_latest.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.subnet_a.id
  availability_zone      = "us-east-1a"
  vpc_security_group_ids = [aws_security_group.server_sg.id]
  associate_public_ip_address = true

     
 user_data = <<-EOF
              #!/bin/bash
              # 1. Update system and install required tools
              sudo apt-get update -y
              sudo apt-get install nginx git -y

              # 2. Start and enable Nginx web server
              sudo systemctl start nginx
              sudo systemctl enable nginx

              # 3. Clean up default Nginx placeholder files
              sudo rm -rf /var/www/html/*

              # 4. Clone the repository into /tmp folder
              cd /tmp
              git clone https://github.com/Ironhack-Archive/online-clone-amazon.git

              # 5. Move all files directly into the web server directory
              sudo cp -r /tmp/online-clone-amazon/. /var/www/html/

              # 6. Set correct permissions so Nginx can read the files
              sudo chown -R www-data:www-data /var/www/html/
              sudo chmod -R 755 /var/www/html/
              
              # 7. Restart Nginx to pick up the changes
              sudo systemctl restart nginx
              EOF

  tags = {
    Name        = "Amazon-vm-A"
    Environment = "Dev-Server"
    Project     = "Terraform-practice"
  }

  # 5. ADD PREVENT DESTROY AND IGNORE CHANGES

  lifecycle {
    prevent_destroy = true
    #ignore_changes  = [tags]
  }
}

resource "aws_instance" "server_b" {
  ami                    = data.aws_ami.ubuntu_latest.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.subnet_b.id
  availability_zone      = "us-east-1b"
  vpc_security_group_ids = [aws_security_group.server_sg.id]
  associate_public_ip_address = true 

     

   user_data = <<-EOF
              #!/bin/bash
              # 1. Update system and install required tools
              sudo apt-get update -y
              sudo apt-get install nginx git -y

              # 2. Start and enable Nginx web server
              sudo systemctl start nginx
              sudo systemctl enable nginx

              # 3. Clean up default Nginx placeholder files
              sudo rm -rf /var/www/html/*

              # 4. Clone the repository into /tmp folder
              cd /tmp
              git clone https://github.com/Ironhack-Archive/online-clone-amazon.git

              # 5. Move all files directly into the web server directory
              sudo cp -r /tmp/online-clone-amazon/. /var/www/html/

              # 6. Set correct permissions so Nginx can read the files
              sudo chown -R www-data:www-data /var/www/html/
              sudo chmod -R 755 /var/www/html/
              
              # 7. Restart Nginx to pick up the changes
              sudo systemctl restart nginx
              EOF

  tags = {
    Name        = "Amazon-vm-B"
    Environment = "Test"
    Project     = "Terraform-practice"
  }

  # 5. ADD PREVENT DESTROY AND IGNORE CHANGES

  lifecycle {
    prevent_destroy = true
    #ignore_changes  = [tags]
  }
}


# 4. LOAD BALANCER & TARGET GROUPS

resource "aws_lb" "main_alb" {
  name               = "main-application-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  tags = {
    Name = "Main-ALB"
  }
}

resource "aws_lb_target_group" "alb_tg" {
  name     = "alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "attach_server_a" {
  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_instance.server_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach_server_b" {
  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_instance.server_b.id
  port             = 80
}


# 6. OUTPUT ELB DNS

output "elb_dns_name" {   # Declares a public print evaluation data lookup query parameter block named elb_dns_name
  description = "The DNS name of the load balancer"  # Provides contextual tooltips documentation outlining what this variable displays
  value       = aws_lb.main_alb.dns_name  # Extracts the newly provisioned fully qualified network tracking domain string address
}
