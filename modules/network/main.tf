# =============================================================================
#  modules/network/main.tf
#  VPC con tres capas de aislamiento replicadas en N zonas de disponibilidad.
# =============================================================================


# -----------------------------------------------------------------------------
#  Consulta las zonas disponibles de la región actual
# -----------------------------------------------------------------------------
# Un "data" consulta, no crea. Le pregunta a AWS qué AZs existen en us-east-1.
#
# ¿Por qué no escribir "us-east-1a" y "us-east-1b" a mano?
# Porque los nombres de AZ están ALEATORIZADOS POR CUENTA. Tu "us-east-1a"
# puede ser físicamente otro datacenter que el "us-east-1a" de un colega.
# AWS lo hizo así para que la gente no concentrara todo en la "a".
#
# Devuelve algo como: ["us-east-1a", "us-east-1b", "us-east-1c", ...]
data "aws_availability_zones" "available" {
  # Filtro: solo zonas operativas.
  # Una AZ también puede estar en "impaired" o "unavailable" (mantenimiento,
  # incidente). Sin este filtro, podrías recibir una zona caída y el apply
  # fallaría a los 10 minutos por algo que no tiene que ver con tu código.
  state = "available"
}


locals {
  # ---------------------------------------------------------------------------
  #  Recorta la lista de AZs a las que realmente vamos a usar
  # ---------------------------------------------------------------------------
  # slice(lista, desde, hasta) → igual que en JavaScript: "desde" incluido,
  # "hasta" excluido. Con az_count = 2 devuelve los índices 0 y 1.
  #
  # El valor de esto: dev usa 2 zonas y prod puede usar 3 cambiando UNA
  # variable. El código no se toca. Eso convierte un script en un módulo.
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)


  # ---------------------------------------------------------------------------
  #  El mapa de subredes: el corazón del módulo
  # ---------------------------------------------------------------------------
  # Objetivo: producir UN mapa plano de 6 entradas con esta forma:
  #
  #   "public-us-east-1a"  = { cidr = "10.0.0.0/24",  az = "...", tier = "public" }
  #   "private-us-east-1a" = { cidr = "10.0.16.0/24", az = "...", tier = "private" }
  #   ...
  #
  # Son dos ciclos anidados: 3 capas x 2 zonas = 6 subredes.
  # Se lee de adentro hacia afuera.
  subnets = merge([

    # CICLO EXTERNO: recorre var.tier_offsets = { public = 0, private = 16, data = 32 }
    # Al iterar un mapa recibes dos variables: la llave y el valor.
    #   vuelta 1 → tier = "public",  offset = 0
    #   vuelta 2 → tier = "private", offset = 16
    #   vuelta 3 → tier = "data",    offset = 32
    #
    # Empieza con "[", así que este ciclo produce una LISTA de 3 mapas.
    for tier, offset in var.tier_offsets : {

      # CICLO INTERNO: recorre las AZs recortadas arriba.
      # Al iterar una lista también recibes dos variables: posición y valor.
      #   vuelta 1 → idx = 0, az = "us-east-1a"
      #   vuelta 2 → idx = 1, az = "us-east-1b"
      #
      # Empieza con "{" y usa "=>", así que produce un MAPA.
      # (Con "[" y sin "=>" produciría una lista. Esa es la diferencia visual.)
      for idx, az in local.azs :

      # La LLAVE del mapa. ${...} es interpolación, igual a las template
      # strings de JavaScript. Resultado: "public-us-east-1a".
      #
      # Esta llave es la IDENTIDAD del recurso en el state. Elegirla bien
      # importa: renombrarla después hace que Terraform destruya y recree.
      "${tier}-${az}" => {

        # HUECO 1 — el CIDR de esta subred.
        # cidrsubnet(prefijo, bits_a_agregar, numero_de_bloque)
        #   - prefijo: el de la VPC
        #   - bits: 8, porque 16 + 8 = 24, y queremos /24
        #   - bloque: sale de sumar DOS valores que ya tienes en este ciclo
        #
        # Compruébalo mentalmente con la capa privada: offset 16, primera
        # zona → bloque 16 → "10.0.16.0/24". Segunda zona → 17.
        cidr = cidrsubnet(var.vpc_cidr, 8, offset + idx)

        # Guardamos la AZ y la capa en el objeto A PROPÓSITO.
        # Dentro del recurso solo vas a tener each.key y each.value; las
        # variables idx, az y tier ya no existirán ahí. Lo que no guardes
        # en este objeto, se pierde. Este objeto es tu diseño.
        az   = az
        tier = tier
      }
    }

    # merge() aplana la lista de 3 mapas en 1 solo, porque for_each necesita
    # un mapa plano.
    #
    # Pero merge() espera los mapas como argumentos SEPARADOS:
    #   merge(m1, m2, m3)     ✅
    #   merge([m1, m2, m3])   ❌ recibe un solo argumento que es una lista
    #
    # El "..." expande la lista en argumentos separados. Es el spread de
    # JavaScript (Math.max(...nums)), solo que en HCL va DETRÁS.
    #
    # ⚠️ Va pegado al corchete: "]...)" funciona, "] ...)" falla con un
    # error de sintaxis que no explica nada. Es el tropiezo más común aquí.
  ]...)
}


# -----------------------------------------------------------------------------
#  La VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # ⚠️ Estos dos NO son opcionales en este proyecto.
  # enable_dns_support   → el resolver de DNS de AWS funciona dentro de la VPC
  # enable_dns_hostnames → las instancias reciben nombre DNS
  #
  # Sin ellos, los VPC Endpoints de la fase 2 no resuelven nombres y el
  # Session Manager de la fase 4 nunca conecta. Es una dependencia oculta:
  # el error aparece tres fases después y no menciona el DNS.
  enable_dns_support   = true
  enable_dns_hostnames = true

  # merge(externos, propios) → el ÚLTIMO gana en caso de conflicto.
  # Así, si quien consume el módulo manda un "Name", el nuestro lo
  # sobrescribe. Al revés, podrían romper los nombres de los recursos.
  tags = merge(var.tags, {
    Name = var.name
  })
}


# -----------------------------------------------------------------------------
#  Internet Gateway
# -----------------------------------------------------------------------------
# La puerta a internet de la VPC. Dos datos que valen para entrevista:
# no cuesta nada y no tiene límite de ancho de banda (el que cuesta y
# estrangula es el NAT Gateway).
#
# Crearlo por sí solo no hace nada: sin una ruta apuntándole es una puerta
# tapiada. Las rutas vienen en el tramo B.
resource "aws_internet_gateway" "this" {
  # HUECO 2 — el ID de la VPC.
  # Referencia el recurso, no repitas el valor. Formato:
  #   tipo_de_recurso.nombre_local.atributo
  #
  # Referenciar es lo que le dice a Terraform "esto depende de aquello" y
  # le permite armar el grafo de dependencias. Igual que en el bootstrap.
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}


# -----------------------------------------------------------------------------
#  Las 6 subredes
# -----------------------------------------------------------------------------
# UN bloque resource, SEIS recursos reales en AWS.
resource "aws_subnet" "this" {
  # for_each recorre el mapa y crea un recurso por entrada.
  #
  # ¿Por qué for_each y no count?
  # Con count las direcciones serían [0], [1], [2]... y la POSICIÓN sería la
  # identidad. Si borras la del medio, todo lo de después se corre un puesto
  # y Terraform destruye y recrea subredes que no querías tocar.
  # Con llaves de texto, borras una y solo se va esa.
  #`
  # Regla general: count solo para "¿existe o no?" (0 o 1). for_each para
  # conjuntos de cosas parecidas pero distinguibles.
  for_each = local.subnets

  # Dentro de un for_each tienes dos variables:
  #   each.key   → la llave: "public-us-east-1a"
  #   each.value → el objeto: { cidr = "...", az = "...", tier = "..." }
  # Los campos del objeto se sacan con punto.

  # HUECO 3 — el ID de la VPC. Lo mismo del hueco 2.
  vpc_id = aws_vpc.this.id

  # HUECO 4 — el CIDR de ESTA subred. Sale de each.value.
  cidr_block = each.value.cidr

  # HUECO 5 — la zona de ESTA subred. Sale de each.value.
  availability_zone = each.value.az

  # HUECO 6 — ¿las instancias que arranquen aquí reciben IP pública?
  # Solo tiene sentido en la capa pública. Necesitas un condicional.
  # El ternario en HCL es igual a JavaScript: condicion ? si : no
  # Y la condición sale de comparar el tier con un string.
  map_public_ip_on_launch = each.value.tier == "public" ? true : false

  tags = merge(var.tags, {
    # each.key ya trae capa y zona: "dev-public-us-east-1a"
    Name = "${var.name}-${each.key}"

    # Este tag no es decoración: en la fase 3 vas a filtrar por él, y en la
    # consola de AWS te salva de adivinar cuál subred es cuál.
    Tier = each.value.tier
  })
}