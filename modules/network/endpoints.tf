# Interface endpoints de SSM: administración sin bastión ni puerto 22.

# La región se consulta; escrita en el nombre del servicio, desplegar en otra
# región falla con un error que no la menciona.
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

  # Resuelve la API de SSM hacia el endpoint sin cambiar las llamadas.
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-${each.value}" })
}
