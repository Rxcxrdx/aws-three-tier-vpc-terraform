# AWS crea este security group con la VPC permitiendo todo el tráfico interno,
# y es el que reciben las instancias lanzadas sin especificar uno. No se puede
# borrar; este recurso lo adopta y lo deja sin ninguna regla.

resource "aws_default_security_group" "this" {
  vpc_id = var.vpc_id

  # Sin bloques ingress ni egress: ambas listas quedan vacías.

  tags = merge(var.tags, { Name = "${var.name}-default-do-not-use" })
}
