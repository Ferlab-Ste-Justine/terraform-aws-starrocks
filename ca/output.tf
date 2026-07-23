output "key" {
  value     = tls_private_key.ca.private_key_pem
  sensitive = true
}

output "certificate" {
  value = tls_self_signed_cert.ca.cert_pem
}
