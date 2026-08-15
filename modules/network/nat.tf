locals {
  # none: sin salida. single: uno compartido. per_az: uno por zona.
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

  # El NAT necesita él mismo una ruta al IGW, así que vive en la subred pública.
  subnet_id     = [for k, v in aws_subnet.this : v.id if v.tags.Tier == "public" && v.availability_zone == each.value][0]
  allocation_id = aws_eip.nat[each.value].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.value}" })

  # Sin referencia directa entre ambos, Terraform no deduce el orden.
  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat" {
  for_each = var.nat_strategy == "none" ? {} : aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"

  # Con per_az, cada tabla apunta al NAT de su propia zona.
  nat_gateway_id = var.nat_strategy == "single" ? aws_nat_gateway.this[local.azs[0]].id : aws_nat_gateway.this[each.key].id
}
