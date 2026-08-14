# =============================================================================
#  VPC de tres capas replicada en N zonas de disponibilidad.
#
#  Las capas (public / private / data) no son solo etiquetas: cada una tiene
#  una tabla de rutas distinta, y esa diferencia es lo que hace que la capa
#  de datos sea inalcanzable desde internet. Ver route_tables.tf.
# =============================================================================

# Las zonas se consultan, no se escriben a mano, porque AWS aleatoriza los
# nombres por cuenta: tu "us-east-1a" puede ser un datacenter físico distinto
# al "us-east-1a" de otra cuenta. Fijarlos en el código hace que el reparto
# entre zonas sea impredecible al desplegar en otra cuenta.
data "aws_availability_zones" "available" {
  # Sin este filtro AWS puede devolver una zona en mantenimiento o caída, y
  # el apply falla diez minutos después por algo ajeno a tu configuración.
  state = "available"
}


locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Mapa plano de subredes, una entrada por combinación de capa y zona:
  #
  #   "public-us-east-1a"  = { cidr = "10.0.0.0/24",  az = "...", tier = "public" }
  #   "private-us-east-1a" = { cidr = "10.0.16.0/24", az = "...", tier = "private" }
  #
  # La clave del mapa es la identidad del recurso en el state, así que
  # renombrarla más adelante destruye y recrea la subred. Por eso combina
  # capa y zona: son los dos únicos datos que no cambian en su vida.
  subnets = merge([
    for tier, offset in var.tier_offsets : {
      for idx, az in local.azs :

      "${tier}-${az}" => {
        # El offset separa las capas y el índice separa las zonas dentro de
        # la capa: private (offset 16) en la primera zona da el bloque 16,
        # o sea 10.0.16.0/24; en la segunda zona, 10.0.17.0/24.
        cidr = cidrsubnet(var.vpc_cidr, 8, offset + idx)

        # Dentro del recurso solo existen each.key y each.value. Lo que no se
        # guarde en este objeto se pierde: este mapa es el contrato interno.
        az   = az
        tier = tier
      }
    }

    # merge() espera mapas como argumentos separados, no una lista. El "..."
    # expande la lista; va pegado al corchete o falla con un error de
    # sintaxis que no explica la causa.
  ]...)
}


resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # No son opcionales en esta arquitectura. Sin resolución DNS, los interface
  # endpoints de SSM no resuelven sus nombres privados y Session Manager
  # nunca conecta. El síntoma aparece mucho después y no menciona el DNS,
  # así que hay un test que lo vigila.
  enable_dns_support   = true
  enable_dns_hostnames = true

  # El orden importa: los tags propios van al final para que quien consuma el
  # módulo no pueda sobrescribir los nombres de los que dependen los filtros.
  tags = merge(var.tags, {
    Name = var.name
  })
}


# El Internet Gateway no cuesta nada y no limita el ancho de banda; el que
# cobra por hora y por GB es el NAT Gateway (ver nat.tf). Por sí solo no
# hace nada: sin una ruta que lo apunte es una puerta tapiada.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}


# -----------------------------------------------------------------------------
#  Las subredes: un bloque, N recursos
# -----------------------------------------------------------------------------
# for_each y no count porque con count la identidad en el state es la
# posición: borrar la subred del medio corre todas las demás un puesto y
# Terraform destruye y recrea recursos que nadie pidió tocar. Con claves de
# texto, borrar una afecta solo a esa.
resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  # Solo la capa pública recibe IP pública automática. Es la mitad de lo que
  # hace "pública" a una subred; la otra mitad es su tabla de rutas.
  map_public_ip_on_launch = each.value.tier == "public"

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"

    # Este tag es un dato del que dependen las asociaciones de rutas y los
    # outputs, no una etiqueta decorativa. Filtrar por él en vez de parsear
    # el nombre de la clave evita depender de una convención de texto.
    Tier = each.value.tier
  })
}
