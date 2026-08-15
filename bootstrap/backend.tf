# Backend parcial. Este stack crea el bucket donde guarda su propio estado, así
# que la primera vez hay que comentar este bloque, aplicar y luego migrar con
# -migrate-state. El procedimiento completo está en README.md.

terraform {
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
