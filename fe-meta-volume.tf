resource "aws_volume_attachment" "fe_meta" {
  for_each = local.fe_nodes

  device_name = "/dev/sdf"
  volume_id   = var.fe_meta_volume_ids[each.key]
  instance_id = aws_instance.fe[each.key].id
}

module "fe_meta_volume" {
  source   = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//data-volumes-aws?ref=v0.55.0"
  for_each = local.fe_nodes

  volumes = [{
    label         = "sr-meta"
    volume_id     = var.fe_meta_volume_ids[each.key]
    mount_path    = "/opt/starrocks/meta"
    mount_options = "defaults,noatime,nofail,x-systemd.device-timeout=5"
  }]
}
