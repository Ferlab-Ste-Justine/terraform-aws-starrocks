output "fe_instance_ids" {
  description = "EC2 instance ids of the StarRocks frontends, keyed by node id."
  value       = { for k, i in aws_instance.fe : k => i.id }
}

output "cn_instance_ids" {
  description = "EC2 instance ids of the StarRocks compute nodes, keyed by node id."
  value       = { for k, i in aws_instance.cn : k => i.id }
}
