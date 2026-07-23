locals {
  fe_nodes = {
    for k, v in var.frontends :
    k => {
      index         = tonumber(regex("[0-9]+$", k)) - 1
      node_name     = "${var.name_prefix}-${var.environment}-fe-${var.cluster_suffix}-${regex("[0-9]+$", k)}"
      is_leader     = v.leader
      instance_type = v.instance_type
      root_gb       = v.root_gb
      meta_gb       = v.meta_gb
      release       = coalesce(v.release, var.starrocks.default_release)
    }
  }

  cn_nodes = {
    for k, v in var.compute_nodes :
    k => {
      index         = tonumber(regex("[0-9]+$", k)) - 1
      node_name     = "${var.name_prefix}-${var.environment}-cn-${var.cluster_suffix}-${regex("[0-9]+$", k)}"
      instance_type = v.instance_type
      root_gb       = v.root_gb
      mem_limit     = v.mem_limit
      release       = coalesce(v.release, var.starrocks.default_release)
    }
  }

  starrocks_node_tar_urls = {
    for k, n in merge(local.fe_nodes, local.cn_nodes) :
    k => "${var.starrocks.download_base_url}/StarRocks-${n.release}-${var.starrocks.arch}.tar.gz"
  }

  fe_fqdns = {
    for k, n in local.fe_nodes :
    k => "ip-${replace(aws_network_interface.fe[k].private_ip, ".", "-")}.${var.region}.compute.internal"
  }

  cn_fqdns_map = {
    for k, n in local.cn_nodes :
    k => "ip-${replace(aws_network_interface.cn[k].private_ip, ".", "-")}.${var.region}.compute.internal"
  }

  leader_key        = one([for k, n in local.fe_nodes : k if n.is_leader])
  leader_fqdn       = local.fe_fqdns[local.leader_key]
  fe_follower_fqdns = [for k, n in local.fe_nodes : local.fe_fqdns[k] if !n.is_leader]
  cn_fqdns          = [for k in keys(local.cn_nodes) : local.cn_fqdns_map[k]]

  dependencies = {
    packages = {
      common   = ["java-17-amazon-corretto-devel"]
      frontend = ["mariadb105"]
    }
    java_home = "/usr/lib/jvm/java-17-amazon-corretto.${var.starrocks.arch == "arm64" ? "aarch64" : "x86_64"}"
  }

  shared_data = {
    enabled              = true
    storage_type         = "S3"
    s3_endpoint          = "https://s3.${var.region}.amazonaws.com"
    s3_path              = "${aws_s3_bucket.starrocks.id}/${var.cluster_suffix}"
    s3_region            = var.region
    use_instance_profile = true
    access_key           = ""
    secret_key           = ""
  }

  ssl_material = jsondecode(aws_secretsmanager_secret_version.starrocks_ssl.secret_string)

  ssl = {
    enabled                = true
    cert                   = local.ssl_material.server_cert
    key                    = local.ssl_material.server_key
    keystore_password      = local.ssl_material.keystore_password
    force_secure_transport = true
  }

  leader_root_password    = { shell_source = "/opt/starrocks-secrets.env" }
  nonleader_root_password = { literal = "" }

  cn_instance_store_mount = <<EOT
#cloud-config
bootcmd:
  - |
    set -e
    DEV=$(lsblk -dno NAME,MODEL | awk '/Amazon EC2 NVMe Instance Storage/{print "/dev/"$1; exit}')
    if [ -n "$DEV" ]; then
      blkid "$DEV" >/dev/null 2>&1 || mkfs.ext4 -F "$DEV"
      mkdir -p /opt/starrocks/storage
      findmnt /opt/starrocks/storage >/dev/null 2>&1 || mount "$DEV" /opt/starrocks/storage
    fi
EOT
}

check "single_fe_leader" {
  assert {
    condition     = length([for k, n in local.fe_nodes : k if n.is_leader]) == 1
    error_message = "Exactly one frontend must have leader = true (got ${length([for k, n in local.fe_nodes : k if n.is_leader])})."
  }
}
