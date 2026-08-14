# El "key" es distinto al del bootstrap ("bootstrap/terraform.tfstate").
# Mismo bucket, ruta diferente. AQUÍ está el aislamiento real entre stacks:
# si dos apuntaran a la misma ruta, compartirían memoria y el apply de uno
# podría borrar lo del otro.

terraform {
  backend "s3" {
    bucket       = "tfstate-aws-three-tier-vpc-089685041957"
    key          = "network/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}