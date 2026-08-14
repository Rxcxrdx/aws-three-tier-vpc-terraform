# =============================================================================
#  Tablas de rutas. Aquí es donde las tres capas dejan de ser una etiqueta
#  y pasan a comportarse distinto:
#
#    public  → ruta 0.0.0.0/0 hacia el Internet Gateway
#    private → ruta 0.0.0.0/0 hacia un NAT (solo salida), o ninguna
#    data    → sin ruta 0.0.0.0/0 en absoluto
# =============================================================================

# Una sola tabla para todas las públicas: comparten destino, no hay razón
# para duplicarla por zona.
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


# --- Datos: aislamiento por ausencia ---
# No hay ningún aws_route apuntando a esta tabla, y esa ausencia es la
# garantía. No existe una regla que diga "prohibido internet": simplemente
# no hay camino. Un test verifica que siga sin haberlo.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-data" })
}

resource "aws_route_table_association" "data" {
  for_each = { for k, v in aws_subnet.this : k => v if v.tags.Tier == "data" }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}


# --- Privadas: una tabla POR ZONA ---
# Aunque con nat_strategy = "single" las tres apunten al mismo NAT, se crean
# separadas desde el principio: pasar a un NAT por zona es entonces cambiar
# una variable, no reestructurar el módulo. La ruta de salida se añade en
# nat.tf, que es quien sabe qué NAT le toca a cada zona.
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
