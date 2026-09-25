resource "aws_network_interface" "fe" {
  for_each = local.fe_nodes

  subnet_id       = element(var.network.subnet_ids, each.value.index)
  security_groups = [var.security_group_id]
  private_ips     = each.value.private_ip == null ? null : [each.value.private_ip]

  tags = { Name = each.value.node_name }
}

resource "aws_network_interface" "cn" {
  for_each = local.cn_nodes

  subnet_id       = element(var.network.subnet_ids, each.value.index)
  security_groups = [var.security_group_id]

  tags = { Name = each.value.node_name }
}

resource "aws_instance" "fe" {
  for_each = local.fe_nodes

  ami                  = var.ami_id
  instance_type        = each.value.instance_type
  iam_instance_profile = var.iam_instance_profile
  key_name             = var.key_pair_name
  user_data            = data.cloudinit_config.fe[each.key].rendered

  network_interface {
    network_interface_id = aws_network_interface.fe[each.key].id
    device_index         = 0
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = each.value.root_gb
    volume_type = "gp3"
    encrypted   = true
    tags        = { Name = each.value.node_name }
  }

  tags = {
    Name        = each.value.node_name
    Application = "starrocks-fe"
  }

  lifecycle {
    ignore_changes       = [ami, user_data]
    replace_triggered_by = [terraform_data.fe_replace_trigger[each.key]]
  }
}

resource "aws_instance" "cn" {
  for_each = local.cn_nodes

  ami                  = var.ami_id
  instance_type        = each.value.instance_type
  iam_instance_profile = var.iam_instance_profile
  key_name             = var.key_pair_name
  user_data            = data.cloudinit_config.cn[each.key].rendered

  network_interface {
    network_interface_id = aws_network_interface.cn[each.key].id
    device_index         = 0
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = each.value.root_gb
    volume_type = "gp3"
    encrypted   = true
    tags        = { Name = each.value.node_name }
  }

  tags = {
    Name        = each.value.node_name
    Application = "starrocks-cn"
  }

  lifecycle {
    ignore_changes       = [ami, user_data]
    replace_triggered_by = [terraform_data.cn_replace_trigger[each.key]]
  }
}

resource "aws_lb_target_group_attachment" "fe_query" {
  for_each = local.fe_nodes

  target_group_arn = var.target_group_arn
  target_id        = aws_instance.fe[each.key].id
}
