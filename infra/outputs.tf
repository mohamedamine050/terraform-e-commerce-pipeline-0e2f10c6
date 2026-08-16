# General identifiers
output "scripts_bucket_name" {
  value = aws_s3_bucket.scripts.bucket
}

output "lambda_producer_name" {
  value = aws_lambda_function.producer.function_name
}
output "lambda_producer_arn" {
  value = aws_lambda_function.producer.arn
}
output "lambda_producer_zip_s3_uri" {
  value = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.producer_zip.key}"
}

output "lambda_streamer_name" {
  value = aws_lambda_function.streamer.function_name
}
output "lambda_streamer_arn" {
  value = aws_lambda_function.streamer.arn
}
output "lambda_streamer_zip_s3_uri" {
  value = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.streamer_zip.key}"
}

output "common_layer_arn" {
  value = aws_lambda_layer_version.common.arn
}
output "common_layer_s3_uri" {
  value = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.common_layer_zip.key}"
}

# EventBridge
output "eventbridge_rule_arn" {
  value = aws_cloudwatch_event_rule.schedule.arn
}

# SQS
output "sqs_queue_url" {
  value = aws_sqs_queue.queue.id
}
output "sqs_queue_arn" {
  value = aws_sqs_queue.queue.arn
}

# Glue jobs (name + ARN + script URI)
output "glue_landing_name" {
  value = aws_glue_job.jobs["landing"].name
}
output "glue_landing_arn" {
  value = aws_glue_job.jobs["landing"].arn
}
output "glue_landing_script_s3_uri" {
  value = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.glue_scripts["landing"].key}"
}

output "glue_processing_name" {
  value = aws_glue_job.jobs["processing"].name
}
output "glue_processing_arn" {
  value = aws_glue_job.jobs["processing"].arn
}
output "glue_processing_script_s3_uri" {
  value = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.glue_scripts["processing"].key}"
}

output "glue_quality_name" {
  value = aws_glue_job.jobs["quality"].name
}
output "glue_quality_arn" {
  value = aws_glue_job.jobs["quality"].arn
}
output "glue_quality_script_s3_uri" {
  value = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.glue_scripts["quality"].key}"
}

output "glue_silvergold_name" {
  value = aws_glue_job.jobs["silvergold"].name
}
output "glue_silvergold_arn" {
  value = aws_glue_job.jobs["silvergold"].arn
}
output "glue_silvergold_script_s3_uri" {
  value = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.glue_scripts["silvergold"].key}"
}

output "glue_rdsload_name" {
  value = aws_glue_job.jobs["rdsload"].name
}
output "glue_rdsload_arn" {
  value = aws_glue_job.jobs["rdsload"].arn
}
output "glue_rdsload_script_s3_uri" {
  value = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.glue_scripts["rdsload"].key}"
}

# Step Function
output "step_function_arn" {
  value = aws_sfn_state_machine.pipeline.arn
}
output "step_function_name" {
  value = aws_sfn_state_machine.pipeline.name
}

# Athena
output "athena_workgroup_name" {
  value = aws_athena_workgroup.wg.name
}
output "athena_database_name" {
  value = aws_athena_database.db.name
}

# RDS
output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}
output "rds_port" {
  value = aws_db_instance.postgres.port
}
output "rds_db_identifier" {
  value = aws_db_instance.postgres.identifier
}
output "rds_username" {
  value = var.rds_username
}
