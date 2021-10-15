output "access_key" {
  description = "The AWS Access Key ID for the IAM deployment user."
  value       = aws_iam_access_key.update_lambda.id
}

output "secret_key" {
  description = "The AWS Secret Key for the IAM deployment user."
  value       = aws_iam_access_key.update_lambda.secret
}

output "rest_api_id" {
  description = "The name of the main rest API Gateway."
  value       = aws_api_gateway_rest_api.rest_api.id
}
