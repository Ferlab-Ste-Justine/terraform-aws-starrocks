resource "aws_volume_attachment" "fe_meta" {
  for_each = local.fe_nodes

  device_name = "/dev/sdf"
  volume_id   = var.fe_meta_volume_ids[each.key]
  instance_id = aws_instance.fe[each.key].id
}

module "fe_meta_volume" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//data-volumes?ref=v0.54.1"

  volumes = [{
    label         = "sr-meta"
    device        = "sdf"
    filesystem    = "xfs"
    mount_path    = "/opt/starrocks/meta"
    mount_options = "defaults,noatime"
    overwrite     = false
  }]
}
