
# ─────────────────────────────────────────────────────────────────────────────
# Remote backend — state stored in S3, locking via DynamoDB
# (Provisioned by the bootstrap/ folder)
# ─────────────────────────────────────────────────────────────────────────────
terraform {
  backend "s3" {
    bucket         = "tfstate-e-commerce-pipeline-u3vk5978"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tflock-e-commerce-pipeline-u3vk5978"
    encrypt        = true
  }
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --------------------------------------------------------------------
# Data sources (default networking)
# --------------------------------------------------------------------
data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --------------------------------------------------------------------
# Random suffix for naming
# --------------------------------------------------------------------
resource "random_string" "suffix" {
  length  = 16
  lower   = true
  upper   = false
  numeric = true
  special = false
}

# --------------------------------------------------------------------
# S3 bucket for all test artifacts
# --------------------------------------------------------------------
resource "aws_s3_bucket" "scripts" {
  bucket        = "data-lake-${random_string.suffix.result}"
  force_destroy = true
}

# --------------------------------------------------------------------
# IAM roles & policies (full access + service role)
# --------------------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role-${random_string.suffix.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_service" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_admin" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "glue_role" {
  name = "glue-role-${random_string.suffix.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_admin" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "stepfn_role" {
  name = "stepfn-role-${random_string.suffix.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "stepfn_admin" {
  role       = aws_iam_role.stepfn_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --------------------------------------------------------------------
# Common Lambda layer (TEST)
# --------------------------------------------------------------------
resource "local_file" "layer_init" {
  filename = "${path.module}/layer/python/__init__.py"
  content  = ""
}

resource "local_file" "common_layer_code" {
  filename   = "${path.module}/layer/python/common.py"
  content    = <<-EOF
def helper():
    return "Hello from TEST layer"
EOF
  depends_on = [local_file.layer_init]
}

data "archive_file" "common_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer"
  output_path = "${path.module}/dist/common_layer.zip"
  depends_on  = [local_file.common_layer_code]
}

resource "aws_s3_object" "common_layer_zip" {
  bucket = aws_s3_bucket.scripts.id
  key    = "layer/common_layer.zip"
  source = data.archive_file.common_layer_zip.output_path
  etag   = data.archive_file.common_layer_zip.output_md5
}

resource "aws_lambda_layer_version" "common" {
  s3_bucket           = aws_s3_bucket.scripts.id
  s3_key              = aws_s3_object.common_layer_zip.key
  layer_name          = "common-layer-${random_string.suffix.result}"
  compatible_runtimes = ["python3.9"]
  source_code_hash    = data.archive_file.common_layer_zip.output_base64sha256
  depends_on          = [aws_s3_object.common_layer_zip]
}

# --------------------------------------------------------------------
# Producer Lambda (TEST)
# --------------------------------------------------------------------
resource "local_file" "producer_code" {
  filename = "${path.module}/src/producer.py"
  content  = <<-EOF
def lambda_handler(event, context):
    return {"statusCode": 200, "body": "Producer TEST"}
EOF
}

data "archive_file" "producer_zip" {
  type        = "zip"
  source_file = local_file.producer_code.filename
  output_path = "${path.module}/dist/producer.zip"
}

resource "aws_s3_object" "producer_zip" {
  bucket = aws_s3_bucket.scripts.id
  key    = "lambda/producer.zip"
  source = data.archive_file.producer_zip.output_path
  etag   = data.archive_file.producer_zip.output_md5
}

resource "aws_lambda_function" "producer" {
  function_name    = "lambda-producer-${random_string.suffix.result}"
  s3_bucket        = aws_s3_bucket.scripts.id
  s3_key           = aws_s3_object.producer_zip.key
  source_code_hash = data.archive_file.producer_zip.output_base64sha256
  handler          = "producer.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 256
  role             = aws_iam_role.lambda_role.arn
  layers           = [aws_lambda_layer_version.common.arn]
  depends_on       = [aws_s3_object.producer_zip, aws_lambda_layer_version.common]
}

# --------------------------------------------------------------------
# Streamer Lambda (TEST)
# --------------------------------------------------------------------
resource "local_file" "streamer_code" {
  filename = "${path.module}/src/streamer.py"
  content  = <<-EOF
def lambda_handler(event, context):
    return {"statusCode": 200, "body": "Streamer TEST"}
EOF
}

data "archive_file" "streamer_zip" {
  type        = "zip"
  source_file = local_file.streamer_code.filename
  output_path = "${path.module}/dist/streamer.zip"
}

resource "aws_s3_object" "streamer_zip" {
  bucket = aws_s3_bucket.scripts.id
  key    = "lambda/streamer.zip"
  source = data.archive_file.streamer_zip.output_path
  etag   = data.archive_file.streamer_zip.output_md5
}

resource "aws_security_group" "lambda_sg" {
  name   = "lambda-sg-${random_string.suffix.result}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lambda_function" "streamer" {
  function_name    = "lambda-streamer-${random_string.suffix.result}"
  s3_bucket        = aws_s3_bucket.scripts.id
  s3_key           = aws_s3_object.streamer_zip.key
  source_code_hash = data.archive_file.streamer_zip.output_base64sha256
  handler          = "streamer.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 256
  role             = aws_iam_role.lambda_role.arn
  layers           = [aws_lambda_layer_version.common.arn]
  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  depends_on = [aws_s3_object.streamer_zip, aws_lambda_layer_version.common]
}

# --------------------------------------------------------------------
# EventBridge rule to trigger producer Lambda
# --------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "eventbridge-rule-${random_string.suffix.result}"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "producer_target" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "producer"
  arn       = aws_lambda_function.producer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.producer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

# --------------------------------------------------------------------
# SQS queue and event source mapping for streamer Lambda
# --------------------------------------------------------------------
resource "aws_sqs_queue" "queue" {
  name = "sqs-queue-${random_string.suffix.result}"
}

resource "aws_lambda_event_source_mapping" "sqs_to_streamer" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = aws_lambda_function.streamer.arn
  batch_size       = 10
  enabled          = true
}

# --------------------------------------------------------------------
# Glue job test scripts (one per job)
# --------------------------------------------------------------------
locals {
  glue_jobs = {
    landing    = "glue/landing.py"
    processing = "glue/processing.py"
    quality    = "glue/quality.py"
    silvergold = "glue/silvergold.py"
    rdsload    = "glue/rdsload.py"
  }
}

resource "local_file" "glue_scripts" {
  for_each = local.glue_jobs
  filename = "${path.module}/${each.value}"
  content  = <<-EOF
print("TEST script for ${each.key} job")
EOF
}

resource "aws_s3_object" "glue_scripts" {
  for_each = local.glue_jobs
  bucket   = aws_s3_bucket.scripts.id
  key      = each.value
  source   = local_file.glue_scripts[each.key].filename
}

resource "aws_glue_job" "jobs" {
  for_each = local.glue_jobs

  name     = "glue-${each.key}-${random_string.suffix.result}"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.glue_scripts[each.key].key}"
    python_version  = "3"
  }

  max_retries       = 0
  timeout           = 10
  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "Standard"
}

# --------------------------------------------------------------------
# Step Function to orchestrate Glue jobs
# --------------------------------------------------------------------
resource "aws_sfn_state_machine" "pipeline" {
  name     = "step_fn_${random_string.suffix.result}"
  role_arn = aws_iam_role.stepfn_role.arn

  definition = jsonencode({
    Comment = "State machine to run Glue jobs sequentially"
    StartAt = "Landing"
    States = {
      Landing = {
        Type       = "Task"
        Resource   = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = aws_glue_job.jobs["landing"].name }
        Next       = "Processing"
      }
      Processing = {
        Type       = "Task"
        Resource   = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = aws_glue_job.jobs["processing"].name }
        Next       = "Quality"
      }
      Quality = {
        Type       = "Task"
        Resource   = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = aws_glue_job.jobs["quality"].name }
        Next       = "SilverGold"
      }
      SilverGold = {
        Type       = "Task"
        Resource   = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = aws_glue_job.jobs["silvergold"].name }
        Next       = "RdsLoad"
      }
      RdsLoad = {
        Type       = "Task"
        Resource   = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = aws_glue_job.jobs["rdsload"].name }
        End        = true
      }
    }
  })
}

# --------------------------------------------------------------------
# Athena workgroup and database
# --------------------------------------------------------------------
resource "aws_athena_workgroup" "wg" {
  name = "athena-${random_string.suffix.result}"
  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.scripts.bucket}/athena-results/"
    }
  }
}

resource "aws_athena_database" "db" {
  name   = "athena_db_${random_string.suffix.result}"
  bucket = aws_s3_bucket.scripts.bucket
}

# --------------------------------------------------------------------
# RDS subnet group (uses default subnets)
# --------------------------------------------------------------------
resource "aws_db_subnet_group" "default" {
  name        = "rds-subnet-group-${random_string.suffix.result}"
  subnet_ids  = data.aws_subnets.default.ids
  description = "Subnet group for RDS using default subnets"
}

# --------------------------------------------------------------------
# RDS security group (open for testing)
# --------------------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name   = "rds-sg-${random_string.suffix.result}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --------------------------------------------------------------------
# PostgreSQL RDS instance (publicly accessible for simplicity)
# --------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  identifier             = "rds-postgres-${random_string.suffix.result}"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.rds_username
  password               = var.rds_password
  publicly_accessible    = true
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  apply_immediately      = true
}
