# Ejemplo mínimo

La arquitectura completa, sin preparativos previos.

```bash
terraform init
terraform apply
```

Lo único que necesitas son credenciales de AWS con permiso para crear redes.

## Por qué este directorio existe

`envs/dev` guarda el state en S3, que es lo correcto para trabajar en equipo, pero obliga a ejecutar antes el `bootstrap/` y a rellenar un `backend.hcl`. Para alguien que solo quiere ver qué hace este módulo, eso son diez minutos de preparación antes de la primera subred.

Aquí el state se queda en un archivo local. Ni bucket, ni bootstrap, ni configuración.

## Qué crea

Una VPC `10.20.0.0/16` con seis subredes en dos zonas, sus tablas de rutas, los tres security groups encadenados, el NACL de la capa de datos y los flow logs.

Los dos recursos que requieren infraestructura persistente vienen desactivados:

```hcl
nat_strategy         = "none"   # sin NAT Gateway
enable_ssm_endpoints = false    # sin interface endpoints
```

La consecuencia es que las subredes privadas no tienen salida a internet. Para desplegarlo tal como funciona en un entorno real, cambia esos dos valores a `"single"` y `true`. Consulta [Salida a internet sin exposición](../../README.md#salida-a-internet-sin-exposición) para entender qué implica cada opción.

## Limpieza

```bash
terraform destroy
```

## Desplegar en otra región

```bash
terraform apply -var region=eu-west-1
```

El módulo no lleva la región escrita en ningún sitio: la consulta con `data "aws_region"`.
