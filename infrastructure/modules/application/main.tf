resource "aws_security_group" "application" {
  name        = "${var.environment}-application-sg"
  description = "Security group for application instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-application-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_launch_template" "application" {
  name_prefix   = "${var.environment}-application-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.application.id]

  user_data = base64encode(
    templatefile("${path.module}/user_data.sh", {
      app_version = var.app_version
    })
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.environment}-instance"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }

  tags = {
    Name        = "${var.environment}-launch-template"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_autoscaling_group" "application" {
  name = "${var.environment}-asg"

  min_size         = 2
  max_size         = 2
  desired_capacity = 2

  vpc_zone_identifier = var.subnet_ids

  target_group_arns = [var.target_group_arn]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.application.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }

    instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 100
      instance_warmup        = 120
    }
  }
}

