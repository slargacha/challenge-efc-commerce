# Variables
variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "database_subnet_ids" {
  description = "IDs de las subnets para base de datos"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  type        = list(string)
}

# Aurora Serverless V2
resource "aws_rds_cluster" "main" {
  cluster_identifier     = "${var.project_name}-aurora"
  engine                = "aurora-postgresql"
  engine_version        = "15.4"
  database_name         = "ecommerce"
  master_username       = "postgres"
  manage_master_user_password = true

  serverlessv2_scaling_configuration {
    max_capacity = 2
    min_capacity = 0.5
  }

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.aurora.id]
  
  storage_encrypted = true
  skip_final_snapshot = true
}

# Aurora Instance
resource "aws_rds_cluster_instance" "main" {
  identifier         = "${var.project_name}-aurora-1"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-aurora"
  subnet_ids = var.database_subnet_ids
}

# Aurora Security Group
resource "aws_security_group" "aurora" {
  name_prefix = "${var.project_name}-aurora"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-cache"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.project_name}-redis"
  description                = "Redis cache para aplicación e-commerce"
  
  node_type                  = "cache.t3.medium"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  
  subnet_group_name = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
}

# Redis Security Group
resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Outputs
output "aurora_cluster_endpoint" {
  value = aws_rds_cluster.main.endpoint
}

output "redis_primary_endpoint" {
  value = aws_elasticache_replication_group.main.primary_endpoint_address
}