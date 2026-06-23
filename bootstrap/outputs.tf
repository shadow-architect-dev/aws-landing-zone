# ==============================================================================
# Terraform Backend Bootstrap Outputs
# ==============================================================================

output "state_bucket_name" {
  value       = aws_s3_bucket.state.id
  description = "The name of the S3 bucket to store Terraform state"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.state_lock.id
  description = "The name of the DynamoDB table for state locking"
}
