# =============================================================================
#  VPC Flow Logs: registra cada conexión (aceptada o rechazada) que pasa
#  por la VPC. Es la respuesta a "¿qué pasó?" cuando algo falle.
# =============================================================================

variable "flow_logs_retention_days" {
  description = "Dias que CloudWatch retiene los flow logs antes de borrarlos."
  type        = number
  default     = 7
}

# Donde se guardan los logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/flow-logs/${var.name}"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(var.tags, { Name = "${var.name}-flow-logs" })
}

# El role que le da permiso al SERVICIO de VPC Flow Logs (no a una
# instancia) para escribir en ese log group. Mismo patrón que en la
# fase 4: un servicio necesita un role para actuar en tu nombre.
resource "aws_iam_role" "flow_logs" {
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
  name_prefix = "${var.name}-flow-logs-"
  role        = aws_iam_role.flow_logs.id

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
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

# El recurso que realmente activa la captura, a nivel de VPC completa
resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL" # ACCEPT + REJECT, no solo uno

  # Formato personalizado: agrega campos que el formato default NO trae
  # y que necesitas para la query de evidencia de HU-06.
  log_format = "$${account-id} $${vpc-id} $${subnet-id} $${instance-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${action} $${flow-direction} $${traffic-path} $${start} $${end}"

  tags = merge(var.tags, { Name = "${var.name}-flow-log" })
}