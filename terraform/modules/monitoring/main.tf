# Variables
variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "api_gateway_id" {
  description = "ID del API Gateway"
  type        = string
}

variable "lambda_function_names" {
  description = "Lista de nombres de funciones Lambda"
  type        = list(string)
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = toset(var.lambda_function_names)
  
  name              = "/aws/lambda/${each.value}"
  retention_in_days = 14
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx" {
  alarm_name          = "${var.project_name}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "API Gateway 4xx errors"

  dimensions = {
    ApiName = "${var.project_name}-api"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  alarm_name          = "${var.project_name}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "API Gateway 5xx errors"

  dimensions = {
    ApiName = "${var.project_name}-api"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", "${var.project_name}-api"],
            [".", "Latency", ".", "."],
            [".", "4XXError", ".", "."],
            [".", "5XXError", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "API Gateway Metrics"
          period  = 300
        }
      }
    ]
  })
}

# Outputs
output "dashboard_url" {
  value = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}