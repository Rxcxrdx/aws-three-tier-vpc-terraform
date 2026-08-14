# =============================================================================
#  Tablas de ruta: le dicen a cada subred hacia dónde enviar tráfico
#  que no es local.
# =============================================================================

# --- Pública: 1 sola tabla, todas las públicas la comparten ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Asocia la tabla pública a las 2 (o N) subredes públicas
resource "aws_route_table_association" "public" {
  for_each = { for k, v in aws_subnet.this : k => v if v.tags.Tier == "public" }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


# --- Datos: 1 sola tabla, SIN rutas hacia afuera. Esto es HU-03. ---
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-data" })
  # No hay aws_route aquí. A propósito: ninguna ruta = sin salida a internet.
}

resource "aws_route_table_association" "data" {
  for_each = { for k, v in aws_subnet.this : k => v if v.tags.Tier == "data" }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}


# --- Privada: 1 tabla POR ZONA. Sin NAT todavía (llega en fase 2), ---
# --- así que por ahora tampoco tiene ruta de salida. Igual que datos. ---
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