resource "aws_iam_role" "node" {
  name = "${var.name_prefix}-${var.environment}-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "shared_data" {
  name        = "${var.name_prefix}-${var.environment}-shared-data"
  description = "Read/write access to the StarRocks shared-data bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [aws_s3_bucket.starrocks.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${aws_s3_bucket.starrocks.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "shared_data" {
  role       = aws_iam_role.node.name
  policy_arn = aws_iam_policy.shared_data.arn
}

resource "aws_iam_policy" "root_password" {
  name        = "${var.name_prefix}-${var.environment}-root-password"
  description = "Read the StarRocks root password secret at boot."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.starrocks_root.arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "root_password" {
  role       = aws_iam_role.node.name
  policy_arn = aws_iam_policy.root_password.arn
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = var.iam.additional_policies

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name_prefix}-${var.environment}-node"
  role = aws_iam_role.node.name
}
