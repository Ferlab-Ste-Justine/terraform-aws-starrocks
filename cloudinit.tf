module "leader_secrets" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//aws-secret-manager?ref=v0.57.0"

  region = var.region
  shell_sources = [{
    script_path = "/opt/starrocks-secrets.env"
    secrets = [{
      secret_id     = var.secrets.root_name
      variable_name = "ROOT_PW"
    }]
  }]
}

module "fe_cloudinit" {
  source   = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//starrocks?ref=v0.57.0"
  for_each = local.fe_nodes

  dependencies         = merge(local.dependencies, { starrocks_tar_url = local.starrocks_node_tar_urls[each.key] })
  timezone             = "America/Montreal"
  node_type            = "fe"
  hosts_file_patch     = { enabled = true, fqdn = local.fe_fqdns[each.key] }
  be_storage_root_path = "/opt/starrocks/storage"

  fe_config = {
    initial_leader = {
      enabled           = each.value.is_leader
      fe_follower_fqdns = each.value.is_leader ? local.fe_follower_fqdns : []
      be_fqdns          = []
      cn_fqdns          = each.value.is_leader ? local.cn_fqdns : []
      root_password     = each.value.is_leader ? local.leader_root_password : local.nonleader_root_password
      users             = []
    }
    initial_follower = {
      enabled        = !each.value.is_leader
      fe_leader_fqdn = each.value.is_leader ? "" : local.leader_fqdn
    }
    ssl             = local.ssl
    iceberg_rest    = { ca_cert = "", env_name = "" }
    meta_dir        = "/opt/starrocks/meta"
    seed_hosts      = values(local.fe_fqdns)
    initial_cluster = each.value.initial_cluster
    shared_data     = local.shared_data
    additional_conf = ["enable_udf = true"]
    ranger          = var.ranger
  }
}

module "fe_security_reverse_proxy_cloudinit" {
  source           = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//http-security-reverse-proxy?ref=v0.57.0"
  cpu_architecture = var.starrocks.arch
  reverse_proxy = {
    server_name     = "starrocks-security-reverse-proxy"
    ip              = "0.0.0.0"
    port            = var.security_reverse_proxy.port
    max_connections = 100
    user = {
      create = false
      name   = "starrocks"
    }
    tls = {
      server_cert = var.ssl.cert
      server_key  = var.ssl.key
    }
    backends = [{
      port = 8030
      path_mappings = [{
        backend_path  = "/metrics"
        frontend_path = "/metrics"
      }]
    }]
  }
}

module "cn_cloudinit" {
  source   = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//starrocks?ref=v0.57.0"
  for_each = local.cn_nodes

  dependencies         = merge(local.dependencies, { starrocks_tar_url = local.starrocks_node_tar_urls[each.key] })
  timezone             = "America/Montreal"
  node_type            = "cn"
  hosts_file_patch     = { enabled = true, fqdn = local.cn_fqdns_map[each.key] }
  be_storage_root_path = "/opt/starrocks/storage"

  fe_config = {
    initial_leader = {
      enabled           = false
      fe_follower_fqdns = []
      be_fqdns          = []
      cn_fqdns          = []
      root_password     = local.nonleader_root_password
      users             = []
    }
    initial_follower = { enabled = false, fe_leader_fqdn = "" }
    ssl              = local.ssl
    iceberg_rest     = { ca_cert = "", env_name = "" }
    meta_dir         = "/opt/starrocks/meta"
    shared_data      = local.shared_data
  }

  cn_config = {
    storage_root_path = "/opt/starrocks/storage"
    mem_limit         = each.value.mem_limit
    priority_networks = var.network.vpc_cidr
  }
}

module "cn_security_reverse_proxy_cloudinit" {
  source           = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//http-security-reverse-proxy?ref=v0.57.0"
  cpu_architecture = var.starrocks.arch
  reverse_proxy = {
    server_name     = "starrocks-security-reverse-proxy"
    ip              = "0.0.0.0"
    port            = var.security_reverse_proxy.port
    max_connections = 100
    user = {
      create = false
      name   = "starrocks"
    }
    tls = {
      server_cert = var.ssl.cert
      server_key  = var.ssl.key
    }
    backends = [{
      port = 8040
      path_mappings = [{
        backend_path  = "/metrics"
        frontend_path = "/metrics"
      }]
    }]
  }
}

data "cloudinit_config" "fe" {
  for_each = local.fe_nodes

  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = module.fe_meta_volume[each.key].configuration
  }

  dynamic "part" {
    for_each = each.value.is_leader ? [module.leader_secrets.configuration] : []
    content {
      content_type = "text/cloud-config"
      content      = part.value
    }
  }

  dynamic "part" {
    for_each = var.security_reverse_proxy.expose_metrics ? [module.fe_security_reverse_proxy_cloudinit.configuration] : []
    content {
      content_type = "text/cloud-config"
      content      = part.value
    }
  }

  part {
    content_type = "text/cloud-config"
    content      = module.fe_cloudinit[each.key].configuration
  }
}

data "cloudinit_config" "cn" {
  for_each = local.cn_nodes

  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = local.cn_instance_store_mount
  }

  dynamic "part" {
    for_each = var.security_reverse_proxy.expose_metrics ? [module.cn_security_reverse_proxy_cloudinit.configuration] : []
    content {
      content_type = "text/cloud-config"
      content      = part.value
    }
  }

  part {
    content_type = "text/cloud-config"
    content      = module.cn_cloudinit[each.key].configuration
  }
}
