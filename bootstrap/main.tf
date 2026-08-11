# =============================================================================
#  bootstrap/main.tf
#  Crea el bucket de S3 donde va a vivir el state de Terraform.
#  Se corre UNA vez en la vida del proyecto y no se vuelve a tocar.
# =============================================================================


# -----------------------------------------------------------------------------
#  BLOQUE data: consulta, no crea
# -----------------------------------------------------------------------------
# "aws_caller_identity" le pregunta a AWS: ¿con qué identidad estoy hablando?
# Devuelve el account_id, el ARN y el user_id de quien corre el comando.
# Es el equivalente en código del `aws sts get-caller-identity` que corrimos.
#
# ¿Para qué? Para NO escribir 089685041957 a mano. Así este mismo código
# funciona en cualquier cuenta sin editarlo. Eso se llama código portable.
#
# Las llaves vacías {} son porque este data no necesita argumentos.
data "aws_caller_identity" "current" {}


# -----------------------------------------------------------------------------
#  BLOQUE locals: apodos internos
# -----------------------------------------------------------------------------
# Un local es un valor calculado que existe solo dentro de este módulo.
# No se configura desde afuera (para eso son las variables) y no se publica
# (para eso son los outputs). Sirve para no repetir la misma expresión.
locals {
  # El nombre del proyecto en un solo lugar. Si cambia, cambia aquí.
  project = "aws-three-tier-vpc"

  # Interpolación: pega texto fijo + dos referencias.
  # Resultado real: "tfstate-aws-three-tier-vpc-089685041957"
  #
  # ¿Por qué meterle el account_id? Porque los nombres de bucket de S3 son
  # únicos EN TODO EL PLANETA. "tfstate-dev" ya lo tiene alguien. El account
  # id garantiza unicidad sin tener que inventar sufijos aleatorios.
  bucket_name = "tfstate-${local.project}-${data.aws_caller_identity.current.account_id}"
}


# -----------------------------------------------------------------------------
#  RECURSO 1: el bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  # Único argumento obligatorio: el nombre.
  bucket = local.bucket_name

  # "lifecycle" NO es de AWS. Es un meta-argumento: una instrucción para
  # Terraform mismo, no para el proveedor. Existe en TODOS los recursos.
  lifecycle {
    # Terraform se niega a destruir este recurso. Falla en el plan, antes
    # de siquiera llamar a AWS.
    #
    # ¿Por qué aquí? Porque este bucket guarda la memoria de toda tu
    # infraestructura. Borrarlo por accidente es el peor día de tu vida.
    #
    # Ojo: si algún día SÍ lo quieres borrar, toca comentar esta línea,
    # correr apply, y luego sí destroy. Es a propósito: te obliga a pensarlo.
    prevent_destroy = true
  }
}


# -----------------------------------------------------------------------------
#  RECURSO 2: versionado — el botón de deshacer
# -----------------------------------------------------------------------------
# Con versioning activo, cada vez que Terraform escribe el state, S3 guarda
# la versión anterior en vez de borrarla. Si el archivo se corrompe, puedes
# restaurar la versión de ayer. ESTE es el recurso que te salva la vida.
resource "aws_s3_bucket_versioning" "tfstate" {
  # ⭐ LA LÍNEA MÁS IMPORTANTE DEL ARCHIVO PARA ENTENDER TERRAFORM.
  #
  # Podría decir local.bucket_name y daría el mismo texto. Pero al escribir
  # aws_s3_bucket.tfstate.id le estoy diciendo a Terraform:
  # "esto depende de ese bucket". Terraform lo mete en su grafo y crea
  # primero el bucket, después el versioning.
  #
  # Con local.bucket_name creería que son independientes, los lanzaría en
  # paralelo, y a veces fallaría con NoSuchBucket.
  #
  # REGLA: nunca repitas un valor si puedes referenciar quien lo produce.
  bucket = aws_s3_bucket.tfstate.id

  # Bloque anidado. Cómo saber si un argumento va suelto (con =) o en bloque
  # (con llaves): el registry te lo dice. Los bloques agrupan cosas
  # relacionadas o cosas que pueden repetirse.
  versioning_configuration {
    status = "Enabled" # OJO: es un string, no true/false. Y con mayúscula.
  }
}


# -----------------------------------------------------------------------------
#  RECURSO 3: cifrado en reposo
# -----------------------------------------------------------------------------
# Cifra los objetos en el disco de AWS. Es transparente: no cambia nada de
# cómo usas el bucket, solo que si alguien roba el disco físico no lee nada.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      # AES256 = llaves administradas por S3 (SSE-S3). Gratis, cero
      # administración. La alternativa es "aws:kms": mejor auditoría y
      # control, pero cuesta y aquí no aporta nada al aprendizaje.
      #
      # Decisión documentada: esto va en un ADR.
      sse_algorithm = "AES256"
    }
  }
}


# -----------------------------------------------------------------------------
#  RECURSO 4: bloqueo de acceso público
# -----------------------------------------------------------------------------
# El interruptor de emergencia. Aunque alguien escriba mal una policy o un
# ACL y abra el bucket al mundo, estos cuatro flags lo anulan.
#
# Los buckets públicos por error son LA fuga de datos más común de AWS.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true # ignora ACLs públicas nuevas
  block_public_policy     = true # rechaza policies que abran el bucket
  ignore_public_acls      = true # ignora las ACLs públicas que ya existieran
  restrict_public_buckets = true # bloquea el acceso anónimo y entre cuentas
}


# -----------------------------------------------------------------------------
#  DATA: generar el JSON de la policy
# -----------------------------------------------------------------------------
# Las policies de IAM son JSON. Podrías escribirlas con jsonencode() o pegar
# un heredoc, pero este data source es mejor: Terraform conoce la estructura
# y si te equivocas en un campo te avisa en el PLAN, no en AWS.
#
# Nota que es un data y no un resource: no crea nada. Solo arma un texto.
data "aws_iam_policy_document" "tfstate" {
  # Una policy tiene uno o más "statement". Cada statement es una regla.
  statement {
    # El sid es un identificador libre. Sirve para que cuando leas la policy
    # en la consola entiendas qué hace cada regla. Ponlo siempre.
    sid = "DenyInsecureTransport"

    # "Deny" o "Allow". Y aquí está la clave de IAM:
    # UN DENY EXPLÍCITO LE GANA A CUALQUIER ALLOW. Siempre. No hay rol,
    # permiso ni administrador que se lo pueda saltar. Es absoluto.
    effect = "Deny"

    # ¿A quién aplica? "*" con identifiers "*" = a cualquiera, sin excepción.
    # En un Deny eso es lo correcto y deseable. En un Allow sería un desastre.
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    # ¿Qué acciones? s3:* = todas las operaciones de S3.
    actions = ["s3:*"]

    # ¿Sobre qué? DOS ARNs, y esto es un error clásico:
    #   - el ARN del bucket        → el bucket como contenedor
    #   - el ARN del bucket + /*   → los objetos que están adentro
    # Son cosas distintas en IAM. Con solo el primero, los objetos quedan
    # sin proteger.
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    # La condición: solo aplica el Deny CUANDO se cumple esto.
    # aws:SecureTransport es una clave de contexto global de AWS: dice si
    # la petición llegó por HTTPS (true) o por HTTP pelado (false).
    #
    # Traducción completa del statement:
    # "A cualquiera, niégale toda operación de S3, cuando NO venga por HTTPS."
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"] # string, no booleano. Cosa de IAM.
    }
  }
}


# -----------------------------------------------------------------------------
#  RECURSO 5: pegarle la policy al bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  # .json es un atributo que ese data source expone: el JSON ya armado.
  policy = data.aws_iam_policy_document.tfstate.json

  # "depends_on" es el otro meta-argumento importante. Fuerza un orden
  # cuando NO hay referencia que lo establezca sola.
  #
  # ¿Por qué aquí? Porque el public_access_block y las policies pelean:
  # si se aplican al mismo tiempo, AWS a veces rechaza la policy.
  #
  # ⚠️ REGLA DE ORO: si sientes que necesitas depends_on, casi siempre es
  # porque te falta una referencia. Este es una de las pocas excepciones
  # legítimas, porque entre estos dos recursos no hay valor que referenciar.
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}


# -----------------------------------------------------------------------------
#  RECURSO 6: ciclo de vida de los objetos
# -----------------------------------------------------------------------------
# Con versioning activo, el bucket guarda TODAS las versiones para siempre.
# Después de 500 apply son 500 copias del state acumulando cobro. Esto limpia.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-noncurrent-versions" # nombre libre, para identificarla
    status = "Enabled"                    # "Enabled" o "Disabled"

    # Obligatorio en el provider 5.x aunque esté vacío.
    # Vacío significa "aplica a todos los objetos del bucket".
    # Si lo omites, el apply falla con un error poco claro.
    filter {}

    # Borra las versiones VIEJAS (no la vigente) después de 90 días.
    # La versión actual del state nunca se toca.
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # Extra de FinOps: las subidas multiparte que quedan a medias siguen
    # cobrando almacenamiento en silencio y NO aparecen al listar el bucket.
    # Este es el tipo de detalle que casi nadie pone.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}