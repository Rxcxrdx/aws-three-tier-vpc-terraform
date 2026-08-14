# modules/network/nat.tf

variable "nat_strategy" {
  description = "single = 1 NAT compartido (dev). per_az = 1 NAT por zona (prod)."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az"], var.nat_strategy)
    error_message = "nat_strategy debe ser 'single' o 'per_az'."
  }
}

locals {
  # Si es "single", solo la primera AZ tiene NAT. Si es "per_az", todas.
  nat_azs = var.nat_strategy == "single" ? [local.azs[0]] : local.azs
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.name}-nat-${each.value}" })
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  # El NAT vive en la subred PÚBLICA de su zona (necesita salir a internet él mismo)
  subnet_id     = [for k, v in aws_subnet.this : v.id if v.tags.Tier == "public" && v.availability_zone == each.value][0]
  allocation_id = aws_eip.nat[each.value].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.value}" })

  depends_on = [aws_internet_gateway.this]
}

# La ruta privada que dejamos vacía en el Tramo B, ahora sí con salida
resource "aws_route" "private_nat" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"

  # Con "single": todas las tablas privadas apuntan al ÚNICO nat.
  # Con "per_az": cada tabla apunta al nat de SU zona.
  nat_gateway_id = var.nat_strategy == "single" ? aws_nat_gateway.this[local.azs[0]].id : aws_nat_gateway.this[each.key].id
}