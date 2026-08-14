# modules/security/default_sg.tf

resource "aws_default_security_group" "this" {
  vpc_id = var.vpc_id

  # Sin ingress ni egress = sin reglas.
  # AWS crea este SG automáticamente con la VPC, con reglas laxas por
  # defecto (permite todo el tráfico interno). Es el primer finding que
  # marca cualquier scanner de seguridad. No se puede borrar, pero sí
  # vaciarlo por completo.

  tags = merge(var.tags, { Name = "${var.name}-default-do-not-use" })
}