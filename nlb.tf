resource "aws_lb" "fe" {
  name               = "${var.name_prefix}-${var.environment}-${var.cluster_suffix}"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.network.subnet_ids

  tags = { Name = "${var.name_prefix}-${var.environment}-${var.cluster_suffix}" }
}

resource "aws_lb_target_group" "fe_query" {
  name     = "${var.name_prefix}-${var.environment}-${var.cluster_suffix}-fe-query"
  port     = 9030
  protocol = "TCP"
  vpc_id   = var.network.vpc_id

  health_check {
    protocol = "TCP"
    port     = 9030
  }
}

resource "aws_lb_target_group_attachment" "fe_query" {
  for_each = local.fe_nodes

  target_group_arn = aws_lb_target_group.fe_query.arn
  target_id        = aws_instance.fe[each.key].id
}

resource "aws_lb_listener" "fe_query" {
  load_balancer_arn = aws_lb.fe.arn
  port              = 9030
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fe_query.arn
  }
}
