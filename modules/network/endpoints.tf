# =============================================================================
#  Interface endpoints de SSM.
#
#  Permiten administrar instancias con Session Manager sin bastión, sin
#  puerto 22 abierto y sin par de claves. El tráfico hacia la API de SSM no
#  sale de la VPC, así que funciona incluso en subredes sin ruta a internet.
#
#  Cuestan por hora y por zona, por eso son desactivables.
# =============================================================================

# La región se consulta en vez de escribirla: con la región fija en el
# nombre del servicio, desplegar en otra región crea endpoints que apuntan
# a un servicio de otra geografía y el apply falla con un error que no
# menciona la región.
data "aws_region" "current" {}

locals {
  ssm_services = var.enable_ssm_endpoints ? toset(["ssm", "ssmmessages", "ec2messages"]) : toset([])
}

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_ssm_endpoints ? 1 : 0

  name_prefix = "${var.name}-vpce-"
  vpc_id      = aws_vpc.this.id
  description = "Permite a las instancias de la VPC alcanzar los endpoints de SSM"

  tags = merge(var.tags, { Name = "${var.name}-vpce" })
}

# Solo HTTPS y solo desde dentro de la VPC: el endpoint es la puerta de
# entrada a la API de AWS desde la red privada, no un servicio público.
resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  count = var.enable_ssm_endpoints ? 1 : 0

  security_group_id = aws_security_group.vpc_endpoints[0].id
  cidr_ipv4         = aws_vpc.this.cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = local.ssm_services

  vpc_id             = aws_vpc.this.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [for k, v in aws_subnet.this : v.id if v.tags.Tier == "private"]
  security_group_ids = [aws_security_group.vpc_endpoints[0].id]

  # Sin esto habría que llamar al endpoint por su nombre largo generado.
  # Con DNS privado, las llamadas normales a la API de SSM se resuelven
  # solas hacia el endpoint. Depende de enable_dns_hostnames en la VPC.
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-${each.value}" })
}
