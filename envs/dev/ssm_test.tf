# Demostración de acceso sin SSH, desactivada por defecto. Levanta una
# instancia en la subred de datos —sin ruta a internet ni par de claves— y
# comprueba que Session Manager conecta igual. Ver README.md.

locals {
  ssm_test_count = var.enable_ssm_test ? 1 : 0
}

# Los endpoints abren el camino de red; este rol abre el de permisos.
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

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  count = local.ssm_test_count

  role       = aws_iam_role.ssm_test[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Un rol no se asigna a una instancia directamente: hace falta este envoltorio.
resource "aws_iam_instance_profile" "ssm_test" {
  count = local.ssm_test_count

  name_prefix = "dev-ssm-test-"
  role        = aws_iam_role.ssm_test[0].name
}

# Los IDs de AMI cambian por región y con cada revisión.
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

  # La subred más restrictiva: si conecta aquí, conecta en cualquier capa.
  subnet_id = module.network.data_subnet_ids[0]

  vpc_security_group_ids = [aws_security_group.ssm_test[0].id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_test[0].name

  # Explícito aunque sea el valor por defecto: no hay vía de acceso alternativa.
  key_name = null

  tags = { Name = "dev-ssm-test" }
}

# Sin reglas de entrada: es el agente quien inicia la conexión hacia fuera.
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
