resource "aws_security_group" "node" {
  name        = "${var.name_prefix}-${var.environment}-${var.cluster_suffix}"
  description = "StarRocks node traffic: query/edit-log/http from the VPC, all node-to-node internal."
  vpc_id      = var.network.vpc_id

  ingress {
    from_port   = 9030
    to_port     = 9030
    protocol    = "tcp"
    cidr_blocks = [var.network.vpc_cidr]
  }

  ingress {
    from_port   = 9010
    to_port     = 9010
    protocol    = "tcp"
    cidr_blocks = [var.network.vpc_cidr]
  }

  ingress {
    from_port   = 8030
    to_port     = 8030
    protocol    = "tcp"
    cidr_blocks = [var.network.vpc_cidr]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-${var.environment}-${var.cluster_suffix}" }
}
