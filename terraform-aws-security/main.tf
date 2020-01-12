resource "aws_security_group" "lb" {
  name = "${var.application_name}-${var.region}-lb"
  description = "controls access to the ALB"
  vpc_id = var.vpc_id

  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}

# Traffic to the ECS Cluster should only come from the ALB
resource "aws_security_group" "ecs_tasks" {
  name = "${var.application_name}-${var.region}-tf-ecs-tasks"
  description = "allow inbound access from the ALB only"
  vpc_id = var.vpc_id

  ingress {
    protocol = "tcp"
    from_port = "${var.app_port}"
    to_port = "${var.app_port}"
    security_groups = [
      "${aws_security_group.lb.id}"]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}

### ALB

resource "aws_alb" "main" {
  name = "${var.application_name}-alb"
  subnets = var.subnets
  security_groups = [
    "${aws_security_group.lb.id}"]
  internal = false

}


resource "aws_alb_target_group" "app" {
  name = "${var.application_name}-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = var.vpc_id
  target_type = "ip"
  deregistration_delay = 10
  depends_on = [
    aws_alb.main]
}


# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.main.id
  port = "80"
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.app.id
    type = "forward"
  }
}
