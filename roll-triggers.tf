resource "terraform_data" "fe_replace_trigger" {
  for_each = local.fe_nodes

  input = local.starrocks_node_tar_urls[each.key]
}

resource "terraform_data" "cn_replace_trigger" {
  for_each = local.cn_nodes

  input = local.starrocks_node_tar_urls[each.key]
}
