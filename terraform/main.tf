# Configuración de Terraform
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Configuración del proveedor AWS
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

# Variables de entrada
variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "e-commerce-jfc"
}

# Módulo de Red
module "networking" {
  source = "./modules/networking"
  
  project_name = var.project_name
}

# Módulo Security
module "security" {
  source = "./modules/security"
  
  project_name = var.project_name
}

# Módulo Frontend
module "frontend" {
  source = "./modules/frontend"
  
  project_name         = var.project_name
  ssl_certificate_arn  = module.security.ssl_certificate_arn
  waf_cloudfront_arn   = module.security.waf_cloudfront_arn
}

# Módulo Backend
module "backend" {
  source = "./modules/backend"
  
  project_name           = var.project_name
  vpc_id                 = module.networking.vpc_id
  private_subnet_ids     = module.networking.private_subnet_ids
  waf_api_gateway_arn    = module.security.waf_api_gateway_arn
  cognito_user_pool_arn  = module.security.cognito_user_pool_arn
  ssl_certificate_arn    = module.security.ssl_certificate_arn
}

# Módulo Data
module "data" {
  source = "./modules/data"
  
  project_name        = var.project_name
  vpc_id              = module.networking.vpc_id
  database_subnet_ids = module.networking.database_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
}

# Módulo Monitoreo
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name          = var.project_name
  api_gateway_id        = module.backend.api_gateway_id
  lambda_function_names = module.backend.lambda_function_names
}

# Outputs
output "api_gateway_url" {
  description = "URL del API Gateway"
  value       = module.backend.api_gateway_url
}

output "cloudfront_url" {
  description = "URL de CloudFront"
  value       = "https://${module.frontend.cloudfront_domain_name}"
}

output "eks_cluster_name" {
  description = "Nombre del cluster EKS"
  value       = module.backend.eks_cluster_name
}

output "alb_dns_name" {
  description = "DNS del ALB"
  value       = module.backend.alb_dns_name
}