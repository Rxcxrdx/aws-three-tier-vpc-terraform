# Las tablas de rutas son lo que hace que cada capa se comporte distinto.

# Una sola tabla para todas las públicas: comparten destino.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = { for k, v in aws_subnet.this : k => v if v.tags.Tier == "public" }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Sin ningún aws_route asociado: el aislamiento de la capa de datos es la
# ausencia de ruta, no una regla de denegación.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-data" })
}

resource "aws_route_table_association" "data" {
  for_each = { for k, v in aws_subnet.this : k => v if v.tags.Tier == "data" }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}

# Una tabla por zona desde el principio: pasar a per_az es cambiar una
# variable en vez de reestructurar. La ruta de salida se añade en nat.tf.
resource "aws_route_table" "private" {
  for_each = toset(local.azs)

  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-private-${each.value}" })
}

resource "aws_route_table_association" "private" {
  for_each = { for k, v in aws_subnet.this : k => v if v.tags.Tier == "private" }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.value.availability_zone].id
}
