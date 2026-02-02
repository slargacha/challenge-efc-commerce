# Variables
variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

# WAF para CloudFront
resource "aws_wafv2_web_acl" "cloudfront" {
  name  = "${var.project_name}-waf-cloudfront"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}WAFCloudFront"
    sampled_requests_enabled   = true
  }
}

# WAF para API Gateway
resource "aws_wafv2_web_acl" "api_gateway" {
  name  = "${var.project_name}-waf-api"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}WAFApiGateway"
    sampled_requests_enabled   = true
  }
}

# Certificate Manager
resource "aws_acm_certificate" "main" {
  domain_name       = "*.ecommerce-jfc.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "ecommerce-jfc.com",
    "api.ecommerce-jfc.com"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Secrets Manager - Aurora
resource "aws_secretsmanager_secret" "aurora_credentials" {
  name        = "${var.project_name}-aurora-credentials"
  description = "Credenciales para base de datos Aurora PostgreSQL"
}

resource "aws_secretsmanager_secret_version" "aurora_credentials" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id
  secret_string = jsonencode({
    username = "postgres"
    password = "MySecurePassword123!"
    engine   = "postgres"
    host     = "aurora-cluster-endpoint"
    port     = 5432
    dbname   = "ecommerce"
  })
}

# Secrets Manager - API Keys
resource "aws_secretsmanager_secret" "api_keys" {
  name        = "${var.project_name}-api-keys"
  description = "API Keys para servicios externos"
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    stripe_api_key   = "sk_test_1234567890abcdef"
    jwt_secret       = "my-super-secret-jwt-key-2024"
  })
}

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]

  schema {
    attribute_data_type = "String"
    name               = "email"
    required           = true
    mutable           = true
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# Usuario de prueba
resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = "testuser@ecommerce-jfc.com"

  attributes = {
    email          = "testuser@ecommerce-jfc.com"
    name           = "Usuario de Prueba"
    email_verified = "true"
  }

  temporary_password = "TempPass123!"
  message_action = "SUPPRESS"
}

# Cognito Identity Pool
resource "aws_cognito_identity_pool" "main" {
  identity_pool_name               = "${var.project_name}-identity"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id     = aws_cognito_user_pool_client.main.id
    provider_name = aws_cognito_user_pool.main.endpoint
  }
}

# Outputs
output "waf_cloudfront_arn" {
  value = aws_wafv2_web_acl.cloudfront.arn
}

output "waf_api_gateway_arn" {
  value = aws_wafv2_web_acl.api_gateway.arn
}

output "ssl_certificate_arn" {
  value = aws_acm_certificate.main.arn
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.main.id
}

output "cognito_user_pool_arn" {
  value = aws_cognito_user_pool.main.arn
}