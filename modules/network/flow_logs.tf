# Registro de conexiones aceptadas y rechazadas de la VPC.

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/vpc/flow-logs/${var.name}"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(var.tags, { Name = "${var.name}-flow-logs" })
}

# El principal es el servicio de Flow Logs, no una instancia.
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

  # Acotada a este log group; los ejemplos habituales usan Resource = "*".
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

  # ACCEPT y REJECT: los intentos bloqueados son la evidencia que interesa.
  traffic_type = "ALL"

  # El formato por defecto no trae flow-direction ni traffic-path.
  log_format = "$${account-id} $${vpc-id} $${subnet-id} $${instance-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${action} $${flow-direction} $${traffic-path} $${start} $${end}"

  tags = merge(var.tags, { Name = "${var.name}-flow-log" })
}
