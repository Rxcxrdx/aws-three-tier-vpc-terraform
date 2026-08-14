# =============================================================================
#  NACL de la capa de datos: la segunda barrera.
#
#  Un security group es de estado: si permites la entrada, la respuesta sale
#  sola. Un NACL no guarda estado y se evalúa a nivel de subred, antes de
#  llegar a la instancia. Por eso hay que declarar entrada y salida por
#  separado.
#
#  Duplicar la restricción no es redundancia inútil: un security group mal
#  configurado por alguien con permisos sobre una instancia no atraviesa el
#  NACL, que se administra a nivel de red.
# =============================================================================

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

# Sin estado quiere decir que esta regla también hace falta para que salgan
# las respuestas a las conexiones que permitió la anterior. Acotada al CIDR
# de la VPC: la capa de datos responde a quien está dentro y a nadie más.
resource "aws_network_acl_rule" "data_egress_vpc" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

# Todo lo demás queda denegado por la regla implícita que cierra cada NACL y
# que no se puede eliminar. No hace falta escribirla.
