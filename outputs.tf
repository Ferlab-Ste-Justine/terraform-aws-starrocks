output "fe_nlb_dns" {
  description = "Internal NLB DNS name fronting the FE query port (9030)."
  value       = aws_lb.fe.dns_name
}

output "node_role_arn" {
  description = "IAM role assumed by the StarRocks nodes."
  value       = aws_iam_role.node.arn
}
