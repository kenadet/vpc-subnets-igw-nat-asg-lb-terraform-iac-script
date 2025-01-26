#2. Application Load Balancer
resource "aws_lb" "app-lb" {
  name               = "app-lb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = aws_subnet.public-subnet[*].id
  depends_on         = [aws_internet_gateway.igw]
}

# Target Group for ALB
resource "aws_lb_target_group" "alb-ec2-tg" {
  name     = "web-server-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name = "alb-ec2-tg"
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.app-lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-ec2-tg.arn
  }
  tags = {
    Name = "alb-listener"
  }
}

#3. Launch Template for EC2 Instances
resource "aws_launch_template" "ec2-launch-template" {
  name = "web-server"

  image_id      = lookup(var.AMIS, var.aws_region) //Copy the ami id from aws console
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2-sg.id]
  }

  user_data = filebase64("init_script.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ec2-web-server"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ec2_asg" {
  name                = "web-server-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 3
  target_group_arns   = [aws_lb_target_group.alb-ec2-tg.arn]
  vpc_zone_identifier = aws_subnet.private-subnet[*].id

  launch_template {
    id      = aws_launch_template.ec2-launch-template.id
    version = "$Latest"
  }

  health_check_type = "EC2"
}

