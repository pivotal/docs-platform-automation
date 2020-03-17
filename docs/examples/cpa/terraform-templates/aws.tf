resource "aws_route53_record" "concourse" {
  name = "ci.${var.environment_name}.${data.aws_route53_zone.hosted.name}"

  zone_id = data.aws_route53_zone.hosted.zone_id
  type    = "A"

  alias {
    name                   = aws_lb.concourse.dns_name
    zone_id                = aws_lb.concourse.zone_id
    evaluate_target_health = true
  }
}

//create a load balancer for concourse
resource "aws_lb" "concourse" {
  name                             = "${var.environment_name}-concourse-lb"
  load_balancer_type               = "network"
  enable_cross_zone_load_balancing = true
  subnets                          = aws_subnet.public-subnet[*].id
}

resource "aws_lb_listener" "concourse-tcp" {
  load_balancer_arn = aws_lb.concourse.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.concourse-tcp.arn
  }
}

resource "aws_lb_listener" "concourse-ssh" {
  load_balancer_arn = aws_lb.concourse.arn
  port              = 2222
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.concourse-ssh.arn
  }
}

resource "aws_lb_listener" "concourse-credhub" {
  load_balancer_arn = aws_lb.concourse.arn
  port              = 8844
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.concourse-credhub.arn
  }
}

resource "aws_lb_listener" "concourse-uaa" {
  load_balancer_arn = aws_lb.concourse.arn
  port              = 8443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.concourse-uaa.arn
  }
}

resource "aws_lb_target_group" "concourse-tcp" {
  name     = "${var.environment_name}-concourse-tg-tcp"
  port     = 443
  protocol = "TCP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    protocol = "TCP"
  }
}

resource "aws_lb_target_group" "concourse-ssh" {
  name     = "${var.environment_name}-concourse-tg-ssh"
  port     = 2222
  protocol = "TCP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    protocol = "TCP"
  }
}

resource "aws_lb_target_group" "concourse-credhub" {
  name     = "${var.environment_name}-concourse-tg-credhub"
  port     = 8844
  protocol = "TCP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    protocol = "TCP"
  }
}

resource "aws_lb_target_group" "concourse-uaa" {
  name     = "${var.environment_name}-concourse-tg-uaa"
  port     = 8443
  protocol = "TCP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    protocol = "TCP"
  }
}

//create a security group for concourse
resource "aws_security_group" "concourse" {
  name   = "${var.environment_name}-concourse-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    cidr_blocks = var.ops_manager_allowed_ips
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }

  ingress {
    cidr_blocks = var.ops_manager_allowed_ips
    protocol    = "tcp"
    from_port   = 2222
    to_port     = 2222
  }

  ingress {
    cidr_blocks = var.ops_manager_allowed_ips
    protocol    = "tcp"
    from_port   = 8844
    to_port     = 8844
  }

  ingress {
    cidr_blocks = var.ops_manager_allowed_ips
    protocol    = "tcp"
    from_port   = 8443
    to_port     = 8443
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }

  tags = merge(
    var.tags,
    { "Name" = "${var.environment_name}-concourse-sg" },
  )
}

output "concourse_url" {
  value = aws_route53_record.concourse.name
}
