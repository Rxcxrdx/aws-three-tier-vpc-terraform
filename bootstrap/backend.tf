# El backend se evalúa antes que variables y locals, por eso el
# nombre del bucket va literal.
terraform {
  backend "s3" {
    bucket       = "tfstate-aws-three-tier-vpc-089685041957"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}