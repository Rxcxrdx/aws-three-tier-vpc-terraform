# Módulo `security`

Los tres security groups de una arquitectura de tres capas, encadenados por referencia, más dos medidas que casi siempre se olvidan: vaciar el security group por defecto y poner un NACL en la capa de datos.

## Uso

```hcl
module "security" {
  source = "../../modules/security"

  name            = "dev"
  vpc_id          = module.network.vpc_id
  vpc_cidr        = module.network.vpc_cidr
  data_subnet_ids = module.network.data_subnet_ids
}
```

## El encadenamiento

```
internet ──80/443──▶ alb ──8080──▶ app ──5432──▶ db
```

Ninguna regla entre capas menciona una dirección IP. `app` autoriza al **security group** `alb`, y `db` autoriza al **security group** `app`.

La diferencia no es estética. Un CIDR autoriza a cualquier cosa que aterrice en esa subred, incluido lo que llegue ahí por error mañana. Una referencia a un security group autoriza solo a las instancias que lo tengan asignado, y sigue siendo correcta después de cualquier renumeración de la red.

El único `0.0.0.0/0` de entrada está en el balanceador, que es su trabajo.

## Entradas

| Nombre | Tipo | Por defecto | Descripción |
|---|---|---|---|
| `vpc_id` | `string` | — | **Obligatorio.** VPC donde crear los recursos. |
| `vpc_cidr` | `string` | — | **Obligatorio.** El NACL de datos permite solo este rango. |
| `name` | `string` | — | **Obligatorio.** Prefijo de nombres y tags. |
| `data_subnet_ids` | `list(string)` | — | **Obligatorio.** Subredes a las que se asocia el NACL. |
| `app_port` | `number` | `8080` | Puerto en el que la aplicación escucha al balanceador. |
| `db_port` | `number` | `5432` | Puerto de la base de datos. 5432 = PostgreSQL. |
| `tags` | `map(string)` | `{}` | Tags adicionales. |

## Salidas

| Nombre | Descripción |
|---|---|
| `alb_security_group_id` | Asignar al balanceador. |
| `app_security_group_id` | Asignar a las instancias o tareas de la aplicación. |
| `db_security_group_id` | Asignar a RDS o equivalente. |
| `data_network_acl_id` | NACL de las subredes de datos. |

## Las dos medidas que se olvidan

**El security group por defecto.** AWS crea uno con cada VPC, permitiendo todo el tráfico entre los recursos que lo tengan, y es el que se asigna a cualquier instancia lanzada sin especificar security group. Es decir: la puerta trasera que salta todo el encadenamiento de arriba. No se puede borrar, así que el módulo lo adopta y lo deja sin ninguna regla. Una instancia que caiga ahí por descuido no puede comunicarse con nada — un fallo ruidoso, que es lo que se quiere.

**El NACL de la capa de datos.** Un security group es de estado y se evalúa en la instancia; un NACL no guarda estado y se evalúa en la frontera de la subred. Un security group mal configurado por alguien con permisos sobre una instancia no atraviesa el NACL, que se administra a nivel de red. Por eso la restricción está duplicada: son dos barreras con dueños distintos, no la misma dos veces.

## Nota sobre la base de datos

`db` no tiene regla de salida, y es deliberado. Al no declarar ninguna, Terraform también elimina la regla de salida abierta que AWS añade por defecto a todo security group nuevo. Si tu base de datos necesita salir —replicación, actualizaciones— tendrás que añadirla explícitamente.
