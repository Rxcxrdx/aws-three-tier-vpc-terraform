# =============================================================================
#  El problema del huevo y la gallina.
#
#  Este stack CREA el bucket donde se guarda el state, incluido el suyo
#  propio. La primera vez no puede usarlo, porque todavía no existe.
#
#  La secuencia es:
#
#    1. Comentar este bloque entero y ejecutar apply. El state queda en un
#       archivo local y el bucket se crea.
#    2. Descomentarlo, copiar backend.hcl.example a backend.hcl con el
#       nombre del bucket recién creado, y ejecutar:
#
#         terraform init -backend-config=backend.hcl -migrate-state
#
#       Terraform sube el state local al bucket que él mismo acaba de crear.
#    3. Borrar terraform.tfstate local (ya está en .gitignore de todos modos).
#
#  Se hace una sola vez por cuenta. A partir de ahí el bucket existe y todos
#  los entornos lo usan.
#
#  El bloque va vacío por la misma razón que en envs/dev: el nombre lleva un
#  número de cuenta y los nombres de bucket son únicos en todo AWS.
# =============================================================================

terraform {
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
