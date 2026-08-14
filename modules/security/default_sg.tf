# =============================================================================
#  El security group por defecto, vaciado.
#
#  AWS crea uno junto con cada VPC y viene permitiendo todo el tráfico entre
#  los recursos que lo tengan asignado. Como es también el que se asigna
#  cuando alguien lanza una instancia sin especificar security group, acaba
#  siendo la puerta trasera por la que se salta el encadenamiento de
#  main.tf. Es de los primeros hallazgos que reporta cualquier escáner.
#
#  No se puede borrar, pero sí dejar sin reglas. Este recurso no lo crea:
#  adopta el que ya existe y lo administra.
# =============================================================================

resource "aws_default_security_group" "this" {
  vpc_id = var.vpc_id

  # Sin bloques ingress ni egress: ambas listas quedan vacías. Cualquier
  # instancia que caiga aquí por descuido no puede comunicarse con nada, que
  # es un fallo mucho más ruidoso y más seguro que el silencio permisivo.

  tags = merge(var.tags, { Name = "${var.name}-default-do-not-use" })
}
