# Bucket de estado de Terraform. Ver README.md.

data "aws_caller_identity" "current" {}

locals {
  project = "aws-three-tier-vpc"

  # Los nombres de bucket son únicos en todo AWS: el account id lo garantiza.
  bucket_name = "tfstate-${local.project}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  lifecycle {
    # Este bucket guarda el estado de todos los entornos.
    prevent_destroy = true
  }
}

# Permite recuperar el estado tras una escritura corrupta.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      # SSE-S3. La alternativa, aws:kms, da auditoría por clave a cambio de coste.
      sse_algorithm = "AES256"
    }
  }
}

# Anula cualquier ACL o policy que abriera el bucket al exterior.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "tfstate" {
  statement {
    sid = "DenyInsecureTransport"

    # Un Deny explícito prevalece sobre cualquier Allow, sin excepción.
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    # El bucket y su contenido son dos recursos distintos en IAM.
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate.json

  # Aplicados a la vez, AWS rechaza la policy de forma intermitente.
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    # Obligatorio en el provider 5.x; vacío aplica a todo el bucket.
    filter {}

    # Solo versiones antiguas. La vigente nunca se toca.
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # Las subidas multiparte incompletas ocupan sin aparecer al listar.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
