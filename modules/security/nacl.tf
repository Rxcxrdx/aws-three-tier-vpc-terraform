# Segunda barrera de la capa de datos: filtra en la frontera de la subred y se
# administra a nivel de red, no de instancia. Ver README.md.

resource "aws_network_acl" "data" {
  vpc_id     = var.vpc_id
  subnet_ids = var.data_subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-data-nacl" })
}

resource "aws_network_acl_rule" "data_ingress_vpc" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

# Las NACL no mantienen estado: sin esta regla, las respuestas no salen.
resource "aws_network_acl_rule" "data_egress_vpc" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

# El resto queda denegado por la regla implícita que cierra toda NACL.
