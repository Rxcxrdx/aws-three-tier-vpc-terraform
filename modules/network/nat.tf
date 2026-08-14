# =============================================================================
#  NAT Gateway: deja que las subredes privadas salgan a internet sin que
#  internet pueda entrar a ellas.
#
#  Es el recurso más caro de esta arquitectura: se paga por hora de
#  existencia más un cargo por GB procesado, incluso sin tráfico. La
#  variable nat_strategy es la palanca de coste contra disponibilidad, y
#  "none" existe para que los ejemplos y los tests no generen factura.
# =============================================================================

locals {
  # none   → sin NAT. Las subredes privadas quedan sin salida a internet.
  # single → un solo NAT en la primera zona. Barato, pero si esa zona cae,
  #          las subredes privadas de TODAS las zonas pierden la salida.
  # per_az → un NAT por zona. El doble o triple de coste a cambio de que la
  #          caída de una zona no arrastre a las demás.
  nat_azs = {
    none   = []
    single = slice(local.azs, 0, 1)
    per_az = local.azs
  }[var.nat_strategy]
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)

  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-${each.value}" })
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  # El NAT vive en la subred pública de su zona: para dar salida a otros,
  # él mismo necesita una ruta hacia el Internet Gateway.
  subnet_id     = [for k, v in aws_subnet.this : v.id if v.tags.Tier == "public" && v.availability_zone == each.value][0]
  allocation_id = aws_eip.nat[each.value].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.value}" })

  # Terraform no puede deducir esta dependencia porque no hay referencia
  # directa entre ambos, pero un NAT creado antes que el IGW nace sin ruta
  # de salida y falla al aprovisionarse.
  depends_on = [aws_internet_gateway.this]
}


# La ruta de salida de cada tabla privada. Con nat_strategy = "none" este
# for_each queda vacío y las subredes privadas se quedan sin ruta 0.0.0.0/0,
# igual que la capa de datos.
resource "aws_route" "private_nat" {
  for_each = var.nat_strategy == "none" ? {} : aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"

  # Con "single" todas las tablas apuntan al único NAT; con "per_az" cada
  # tabla apunta al de su propia zona. Enrutar a la zona equivocada anula
  # la alta disponibilidad que se está pagando.
  nat_gateway_id = var.nat_strategy == "single" ? aws_nat_gateway.this[local.azs[0]].id : aws_nat_gateway.this[each.key].id
}
