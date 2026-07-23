resource "tls_private_key" "starrocks" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "starrocks" {
  key_name   = "starrocks-${var.environment}-keypair"
  public_key = tls_private_key.starrocks.public_key_openssh
}

resource "aws_secretsmanager_secret" "starrocks_keypair" {
  name = "starrocks-${var.environment}-keypair"
}

resource "aws_secretsmanager_secret_version" "starrocks_keypair" {
  secret_id     = aws_secretsmanager_secret.starrocks_keypair.id
  secret_string = tls_private_key.starrocks.private_key_pem
}


resource "random_password" "starrocks_root" {
  length  = 30
  lower   = true
  numeric = true
  upper   = true
  special = false
}

resource "aws_secretsmanager_secret" "starrocks_root" {
  name = "starrocks-${var.environment}-root-pw"
}

resource "aws_secretsmanager_secret_version" "starrocks_root" {
  secret_id     = aws_secretsmanager_secret.starrocks_root.id
  secret_string = random_password.starrocks_root.result
}


module "starrocks_ca" {
  source      = "./ca"
  common_name = "qlin-${var.environment}-starrocks"
}

resource "aws_secretsmanager_secret" "starrocks_ca_cert" {
  name = "starrocks-${var.environment}-ca-cert"
}

resource "aws_secretsmanager_secret_version" "starrocks_ca_cert" {
  secret_id     = aws_secretsmanager_secret.starrocks_ca_cert.id
  secret_string = module.starrocks_ca.certificate
}

resource "tls_private_key" "starrocks_ssl_server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "starrocks_ssl_server" {
  private_key_pem = tls_private_key.starrocks_ssl_server.private_key_pem

  subject {
    common_name  = "qlin-${var.environment}-starrocks-server"
    organization = "Ferlab"
  }

  dns_names = ["starrocks-${var.environment}.${var.domain_name}"]
}

resource "tls_locally_signed_cert" "starrocks_ssl_server" {
  cert_request_pem   = tls_cert_request.starrocks_ssl_server.cert_request_pem
  ca_private_key_pem = module.starrocks_ca.key
  ca_cert_pem        = module.starrocks_ca.certificate

  validity_period_hours = 100 * 365 * 24
  early_renewal_hours   = 365 * 24

  allowed_uses = [
    "server_auth",
  ]

  is_ca_certificate = false
}

resource "random_password" "starrocks_ssl_keystore" {
  length  = 30
  lower   = true
  numeric = true
  upper   = true
  special = false
}

resource "aws_secretsmanager_secret" "starrocks_ssl" {
  name = "starrocks-${var.environment}-ssl"
}

resource "aws_secretsmanager_secret_version" "starrocks_ssl" {
  secret_id = aws_secretsmanager_secret.starrocks_ssl.id
  secret_string = jsonencode({
    server_cert       = tls_locally_signed_cert.starrocks_ssl_server.cert_pem
    server_key        = tls_private_key.starrocks_ssl_server.private_key_pem
    keystore_password = random_password.starrocks_ssl_keystore.result
  })
}
