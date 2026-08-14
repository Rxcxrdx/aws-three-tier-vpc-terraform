# Bootstrap: el bucket de state

Crea el bucket de S3 donde los entornos guardan su state, con versionado, cifrado en reposo, bloqueo de acceso público y una política que rechaza cualquier conexión sin TLS.

**Se ejecuta una sola vez por cuenta.** Después, todos los entornos lo usan.

## El problema del huevo y la gallina

Este stack crea el bucket donde se guarda el state, incluido el suyo propio. La primera vez ese bucket todavía no existe, así que no puede usarlo como backend. Se resuelve en dos pasos:

```bash
# 1. Comenta el bloque backend de backend.tf. El state queda en local.
terraform init
terraform apply
terraform output -raw tfstate_bucket_name

# 2. Descomenta el bloque y migra el state al bucket recién creado.
cp backend.hcl.example backend.hcl    # pon dentro el nombre del bucket
terraform init -backend-config=backend.hcl -migrate-state
```

Terraform sube el state local al bucket que él mismo acaba de crear. A partir de ahí, `terraform.tfstate` local sobra y ya está en `.gitignore`.

## Por qué el nombre del bucket no está en el código

Lleva el número de cuenta (`tfstate-aws-three-tier-vpc-<ACCOUNT_ID>`) porque los nombres de bucket de S3 son únicos **en todo AWS**, no por cuenta. Escribirlo en `backend.tf` haría que este repositorio solo funcionara en la cuenta de quien lo escribió: cualquier otra persona fallaría en el primer `init` con un error de permisos que no explica la causa.

El bloque `backend` va vacío y los valores llegan por `-backend-config`. El backend se evalúa antes que las variables y los locals, así que no hay forma de calcularlo dentro de Terraform.

## Decisiones

**Versionado activado.** El state es el único registro de qué existe en la cuenta. Un `apply` corrupto o un borrado accidental se recuperan volviendo a una versión anterior — como hicimos al auditar el historial de operaciones de este mismo proyecto.

**Bloqueo nativo de S3** (`use_lockfile = true`), disponible desde Terraform 1.11. Antes hacía falta una tabla de DynamoDB dedicada solo a impedir dos `apply` simultáneos: un recurso más que crear, pagar y mantener.

**`prevent_destroy` en el bucket.** Un `terraform destroy` en este directorio borraría el state de todos los entornos. El ciclo de vida lo impide; para eliminarlo de verdad hay que quitar esa línea a conciencia.

**La política deniega el tráfico sin TLS** con una condición sobre `aws:SecureTransport`, aplicada a todos los principales. Es lo primero que marca cualquier revisión de seguridad sobre un bucket.

## Coste

El bucket almacena unos pocos kilobytes. El gasto es indistinguible de cero, y por eso este stack **no se destruye** al terminar una sesión de trabajo, a diferencia de los entornos.
