# modules/security/nacl.tf

variable "data_subnet_ids" {
  description = "IDs de las subredes de datos donde aplicar el NACL."
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR de la VPC, para permitir solo trafico interno."
  type        = string
}

resource "aws_network_acl" "data" {
  vpc_id     = var.vpc_id
  subnet_ids = var.data_subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-data-nacl" })
}

# Entrada: solo desde dentro de la VPC
resource "aws_network_acl_rule" "data_ingress_vpc" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

# Salida: solo hacia dentro de la VPC. Nada hacia 0.0.0.0/0.
resource "aws_network_acl_rule" "data_egress_vpc" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

# Todo lo demás queda denegado implícitamente: las NACL tienen un
# "deny all" al final que no se puede quitar. No hace falta escribirlo.