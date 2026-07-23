resource "aws_s3_bucket" "starrocks" {
  bucket = "starrocks-data-${var.account_id}-${var.region}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "starrocks" {
  bucket = aws_s3_bucket.starrocks.id

  versioning_configuration {
    status = "Enabled"
  }
}
