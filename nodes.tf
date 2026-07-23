resource "aws_network_interface" "fe" {
  for_each = local.fe_nodes

  subnet_id       = element(var.network.subnet_ids, each.value.index)
  security_groups = [aws_security_group.node.id]

  tags = { Name = each.value.node_name }
}

resource "aws_network_interface" "cn" {
  for_each = local.cn_nodes

  subnet_id       = element(var.network.subnet_ids, each.value.index)
  security_groups = [aws_security_group.node.id]

  tags = { Name = each.value.node_name }
}

resource "aws_instance" "fe" {
  for_each = local.fe_nodes

  ami                  = var.ami_id
  instance_type        = each.value.instance_type
  iam_instance_profile = aws_iam_instance_profile.node.name
  key_name             = aws_key_pair.starrocks.key_name
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
  iam_instance_profile = aws_iam_instance_profile.node.name
  key_name             = aws_key_pair.starrocks.key_name
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
