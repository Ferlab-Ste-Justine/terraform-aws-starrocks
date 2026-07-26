locals {
  fe_roll_triggers = {
    for k, n in local.fe_nodes :
    k => n.generation == 0 ? local.starrocks_node_tar_urls[k] : "${local.starrocks_node_tar_urls[k]}#gen-${n.generation}"
  }
  cn_roll_triggers = {
    for k, n in local.cn_nodes :
    k => n.generation == 0 ? local.starrocks_node_tar_urls[k] : "${local.starrocks_node_tar_urls[k]}#gen-${n.generation}"
  }
}

resource "terraform_data" "fe_replace_trigger" {
  for_each = local.fe_nodes

  input = local.fe_roll_triggers[each.key]
}

resource "terraform_data" "cn_replace_trigger" {
  for_each = local.cn_nodes

  input = local.cn_roll_triggers[each.key]
}
