# =============================================================================
#  Demostración de acceso sin SSH (opcional, apagada por defecto).
#
#  Levanta una instancia en la subred de DATOS —la más aislada de las seis,
#  sin ruta a internet— y comprueba que Session Manager conecta igual. Si
#  funciona ahí, funciona en cualquier capa.
#
#  Se activa con enable_ssm_test = true. Está apagada porque es evidencia,
#  no infraestructura, y una instancia encendida cuesta dinero.
#
#      terraform apply -var enable_ssm_test=true
#      aws ssm start-session --target $(terraform output -raw instance_id)
#
#  Que esa sesión abra sin par de claves, sin puerto 22 y sin bastión es
#  toda la demostración.
# =============================================================================

locals {
  ssm_test_count = var.enable_ssm_test ? 1 : 0
}

# Los endpoints abren el camino de RED hacia la API de SSM; este rol abre el
# de PERMISOS. Hacen falta los dos, y el error cuando falta uno no dice cuál.
resource "aws_iam_role" "ssm_test" {
  count = local.ssm_test_count

  name_prefix = "dev-ssm-test-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Política gestionada por AWS con los permisos exactos del agente. Escribirla
# a mano significa mantenerla cada vez que SSM añade una acción.
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  count = local.ssm_test_count

  role       = aws_iam_role.ssm_test[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Un rol no se asigna a una instancia directamente: el instance profile es
# el intermediario obligatorio entre ambos.
resource "aws_iam_instance_profile" "ssm_test" {
  count = local.ssm_test_count

  name_prefix = "dev-ssm-test-"
  role        = aws_iam_role.ssm_test[0].name
}

# Los IDs de AMI cambian por región y con cada revisión. Consultarla evita
# un valor que caduca y que además ata el código a una sola región.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "ssm_test" {
  count = local.ssm_test_count

  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  # La subred de datos: sin ruta 0.0.0.0/0. La conexión solo puede llegar
  # por los interface endpoints, que es justo lo que se quiere demostrar.
  subnet_id = module.network.data_subnet_ids[0]

  vpc_security_group_ids = [aws_security_group.ssm_test[0].id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_test[0].name

  # Explícito, aunque sea el valor por defecto: sin par de claves. Es la
  # prueba en una línea de que no hay una vía de acceso alternativa.
  key_name = null

  tags = { Name = "dev-ssm-test" }
}

# Solo salida HTTPS hacia la propia VPC, que es donde viven los endpoints.
# Ninguna regla de entrada: nadie inicia una conexión hacia esta instancia,
# ni siquiera para administrarla. Es el agente quien llama hacia fuera.
resource "aws_security_group" "ssm_test" {
  count = local.ssm_test_count

  name_prefix = "dev-ssm-test-"
  vpc_id      = module.network.vpc_id
  description = "Salida HTTPS hacia los endpoints de SSM"

  tags = { Name = "dev-ssm-test" }
}

resource "aws_vpc_security_group_egress_rule" "ssm_test_https" {
  count = local.ssm_test_count

  security_group_id = aws_security_group.ssm_test[0].id
  cidr_ipv4         = module.network.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Hacia los interface endpoints de SSM"
}
