# Módulo `network`

VPC de tres capas replicada en N zonas de disponibilidad, con las tablas de rutas que hacen que cada capa se comporte de forma distinta.

Crea una VPC, un Internet Gateway, `3 × az_count` subredes, una tabla de rutas por capa (y una por zona en la capa privada), opcionalmente NAT Gateways, los interface endpoints de SSM y los flow logs.

## Uso

```hcl
module "network" {
  source = "../../modules/network"

  name     = "dev"
  vpc_cidr = "10.0.0.0/16"
  az_count = 2

  nat_strategy = "single"
}
```

Para pruebas o demostraciones, sin infraestructura persistente:

```hcl
module "network" {
  source = "../../modules/network"

  name                 = "demo"
  nat_strategy         = "none"
  enable_ssm_endpoints = false
}
```

## Entradas

| Nombre | Tipo | Por defecto | Descripción |
|---|---|---|---|
| `name` | `string` | — | **Obligatorio.** Prefijo de nombres y tags. |
| `vpc_cidr` | `string` | `10.0.0.0/16` | Rango de la VPC. Validado como CIDR IPv4. |
| `az_count` | `number` | `2` | Zonas a usar. Entre 2 y 4; menos de 2 rompe la alta disponibilidad. |
| `tier_offsets` | `map(number)` | `{public=0, private=16, data=32}` | Bloque /24 inicial de cada capa. Múltiplos de 16. |
| `nat_strategy` | `string` | `single` | `none`, `single` o `per_az`. Ver abajo. |
| `enable_ssm_endpoints` | `bool` | `true` | Interface endpoints de SSM para administración sin SSH. |
| `enable_flow_logs` | `bool` | `true` | Registro de conexiones en CloudWatch. |
| `flow_logs_retention_days` | `number` | `7` | Retención de los flow logs. |
| `tags` | `map(string)` | `{}` | Tags adicionales para todos los recursos. |

## Salidas

| Nombre | Descripción |
|---|---|
| `vpc_id` | ID de la VPC. |
| `vpc_cidr` | Rango de la VPC, para reglas de firewall. |
| `public_subnet_ids` | Subredes públicas. |
| `private_subnet_ids` | Subredes privadas. |
| `data_subnet_ids` | Subredes de datos. |
| `private_subnet_ids_by_az` | Subredes privadas indexadas por zona. |
| `azs` | Zonas en uso. |
| `nat_gateway_ids` | NAT creados. Vacío con `nat_strategy = none`. |
| `flow_logs_group_name` | Log group de flow logs, o `null` si están apagados. |

## `nat_strategy`

| Valor | NAT creados | Qué pasa si cae una zona |
|---|---|---|
| `none` | 0 | Las subredes privadas no tienen salida en ningún caso. |
| `single` | 1 | Si cae la zona del NAT, **todas** las subredes privadas pierden la salida. |
| `per_az` | 1 por zona | Las demás zonas siguen saliendo con normalidad. |

Las tablas de rutas privadas se crean por zona en los tres casos, así que cambiar de `single` a `per_az` es cambiar una variable.

## Direccionamiento

Con los valores por defecto y `az_count = 2`:

| Capa | Zona a | Zona b |
|---|---|---|
| `public` | 10.0.0.0/24 | 10.0.1.0/24 |
| `private` | 10.0.16.0/24 | 10.0.17.0/24 |
| `data` | 10.0.32.0/24 | 10.0.33.0/24 |

La separación de 16 en 16 deja espacio para crecer hasta 16 zonas por capa sin renumerar nada.

## Notas

- `enable_dns_support` y `enable_dns_hostnames` están fijados a `true` y no son configurables: sin ellos los endpoints de SSM no resuelven y Session Manager no conecta.
- La región se obtiene con `data "aws_region"`, así que el módulo funciona en cualquier región sin cambios.
