# =============================================================================
#  VPC Flow Logs: registra cada conexión aceptada o rechazada de la VPC.
#
#  Es la única forma de demostrar después que el aislamiento funcionó. Sin
#  esto, "la capa de datos no habla con internet" es una afirmación sobre
#  la configuración; con esto, es una consulta con resultados.
# =============================================================================

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/vpc/flow-logs/${var.name}"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(var.tags, { Name = "${var.name}-flow-logs" })
}

# El servicio de Flow Logs escribe en tu cuenta, así que necesita un rol que
# asumir. El principal es el servicio, no una instancia: nadie inicia sesión
# con este rol.
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name_prefix = "${var.name}-flow-logs-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name_prefix = "${var.name}-flow-logs-"
  role        = aws_iam_role.flow_logs[0].id

  # Acotado al log group de esta VPC. Los ejemplos que circulan usan
  # Resource = "*", que da permiso de escritura sobre todos los logs de la
  # cuenta a cambio de nada.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.this.id
  iam_role_arn         = aws_iam_role.flow_logs[0].arn
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  log_destination_type = "cloud-watch-logs"

  # ACCEPT y REJECT. Registrar solo lo aceptado deja fuera justo la
  # evidencia que interesa: los intentos que el aislamiento bloqueó.
  traffic_type = "ALL"

  # El formato por defecto no incluye flow-direction ni traffic-path, que
  # son los campos que distinguen una salida a internet de una respuesta a
  # una conexión entrante.
  log_format = "$${account-id} $${vpc-id} $${subnet-id} $${instance-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${action} $${flow-direction} $${traffic-path} $${start} $${end}"

  tags = merge(var.tags, { Name = "${var.name}-flow-log" })
}
