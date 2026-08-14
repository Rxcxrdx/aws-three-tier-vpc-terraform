# =============================================================================
#  Backend parcial.
#
#  El bloque va vacío a propósito: el nombre del bucket de state incluye un
#  número de cuenta, y los nombres de bucket de S3 son únicos en todo AWS.
#  Escribirlo aquí haría que este repositorio solo funcionara en la cuenta
#  de quien lo escribió.
#
#  Los valores se pasan al inicializar:
#
#      cp backend.hcl.example backend.hcl   # y rellenar
#      terraform init -backend-config=backend.hcl
#
#  backend.hcl está en .gitignore. El .example, no.
#
#  El "key" separa este stack del bootstrap dentro del mismo bucket. Dos
#  stacks apuntando a la misma ruta comparten state, y el apply de uno
#  puede destruir los recursos del otro.
# =============================================================================

terraform {
  backend "s3" {
    key     = "network/dev/terraform.tfstate"
    encrypt = true

    # Locking nativo de S3, disponible desde Terraform 1.11. Antes hacía
    # falta una tabla de DynamoDB solo para esto.
    use_lockfile = true
  }
}
