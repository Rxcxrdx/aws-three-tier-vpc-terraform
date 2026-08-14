# =============================================================================
#  Instancia mínima para probar HU-03 (aislamiento de datos) y HU-05
#  (acceso sin SSH). No es parte del producto: es la evidencia.
# =============================================================================

# --- El role que le da permiso al agente SSM para hablar con el servicio ---
# Sin esto, aunque los VPC Endpoints estén perfectos, el agente no tiene
# AUTORIZACIÓN para usarlos. Los endpoints abren el camino de RED; el role
# abre el camino de PERMISOS. Son cosas distintas y se necesitan las dos.
resource "aws_iam_role" "ssm_test" {
  name_prefix = "dev-ssm-test-"

  # "Quién puede asumir este role": el propio servicio EC2.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Policy administrada por AWS con los permisos exactos que el agente
# SSM necesita. No la escribimos a mano: AWS la mantiene actualizada.
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ssm_test.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# El "instance profile" es el envoltorio que conecta un IAM role con una
# instancia EC2. Un role no se le asigna a una instancia directamente;
# necesita este intermediario.
resource "aws_iam_instance_profile" "ssm_test" {
  name_prefix = "dev-ssm-test-"
  role        = aws_iam_role.ssm_test.name
}

# --- La AMI más reciente de Amazon Linux, sin hardcodear un ID ---
# Los IDs de AMI cambian por región y con el tiempo. Este data source
# siempre trae la última versión válida para tu región.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# --- La instancia, en la subred de DATOS (la más restrictiva) ---
resource "aws_instance" "ssm_test" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  # La subred más aislada de las 6. Si SSM conecta aquí, conecta en
  # cualquier lado. Es la prueba más exigente posible.
  subnet_id = module.network.data_subnet_ids[0]

  # OJO: no lleva ningún security group de aplicación (app/db). Le creamos
  # uno mínimo, solo para permitir la salida hacia los VPC Endpoints.
  vpc_security_group_ids = [aws_security_group.ssm_test.id]

  iam_instance_profile = aws_iam_instance_profile.ssm_test.name

  # Sin esto NO hay forma de entrar. Es la prueba, en una sola línea, de
  # que HU-05 se cumple: cero llave, cero par de claves generado.
  key_name = null

  tags = { Name = "dev-ssm-test", Environment = "dev" }
}

# SG mínimo: solo egress hacia dentro de la VPC (donde viven los endpoints).
# Nada de ingress — nadie necesita iniciar conexión HACIA esta instancia.
resource "aws_security_group" "ssm_test" {
  name_prefix = "dev-ssm-test-"
  vpc_id      = module.network.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.network.vpc_cidr]
  }

  tags = { Name = "dev-ssm-test" }
}