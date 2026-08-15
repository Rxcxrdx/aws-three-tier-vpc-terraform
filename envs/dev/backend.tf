# Backend parcial: el nombre del bucket lleva el account id y los nombres de
# bucket son únicos en todo AWS, así que se aporta al inicializar.
#
#   cp backend.hcl.example backend.hcl
#   terraform init -backend-config=backend.hcl

terraform {
  backend "s3" {
    # El key aísla este stack del resto dentro del mismo bucket.
    key     = "network/dev/terraform.tfstate"
    encrypt = true

    # Locking nativo de S3, desde Terraform 1.11. Antes requería DynamoDB.
    use_lockfile = true
  }
}
