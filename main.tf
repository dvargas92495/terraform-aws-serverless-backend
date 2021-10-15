locals {
  # Still TODO
  # - filter out non js/ts file extensions
  # - filter out paths that start in underscore
  paths = length(var.paths) > 0 ? var.paths : [
    for path in fileset("${path.module}/functions", "**"): replace(path, "/\\.ts$/", "")
  ]

  path_parts = {
     for path in local.paths:
     path => split("/", path)
  }

  methods = {
      for path in local.paths:
      path => local.path_parts[path][length(local.path_parts[path]) - 1]
  }

  resources = distinct([
    for path in local.paths: local.path_parts[path][0]
  ])

  function_names = {
    for lambda in local.paths:
    lambda => join("_", local.path_parts[lambda])
  }
}

# lambda resource requires either filename or s3... wow
data "archive_file" "dummy" {
  type        = "zip"
  output_path = "./dummy.zip"

  source {
    content   = "// TODO IMPLEMENT"
    filename  = "dummy.js"
  }
}

data "aws_iam_policy_document" "assume_lambda_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_execution_policy" {
  statement {
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "ses:sendEmail",
      "lambda:InvokeFunction",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:DeleteObject",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "arn:aws:iam::*:role/${var.api_name}-lambda-execution"
    ]
  }
}

resource "aws_iam_policy" "lambda_execution_policy" {
  name = "${var.api_name}-lambda-execution"
  policy = data.aws_iam_policy_document.lambda_execution_policy.json
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.api_name}-lambda-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda_policy.json
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
}

resource "aws_api_gateway_rest_api" "rest_api" {
  name        = var.api_name
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  binary_media_types = [
    "multipart/form-data",
    "application/octet-stream"
  ]

  tags = var.tags
}

resource "aws_api_gateway_resource" "resource" {
  for_each    = toset(local.resources)

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = each.value
}

resource "aws_lambda_function" "lambda_function" {
  for_each      = toset(local.paths)

  function_name = "${var.api_name}_${local.function_names[each.value]}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "${local.function_names[each.value]}.handler"
  filename      = data.archive_file.dummy.output_path
  runtime       = "nodejs12.x"
  publish       = false
  timeout       = 10

  tags = var.tags
}

resource "aws_api_gateway_method" "method" {
  for_each      = toset(local.paths)

  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.resource[local.path_parts[each.value][0]].id
  http_method   = upper(local.methods[each.value])
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  for_each                = toset(local.paths)

  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.resource[local.path_parts[each.value][0]].id
  http_method             = upper(local.methods[each.value])
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function[each.value].invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  for_each      = toset(local.paths)

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function[each.value].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_method" "options" {
  for_each      = toset(local.resources)

  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.resource[each.value].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "mock" {
  for_each             = toset(local.resources)

  rest_api_id          = aws_api_gateway_rest_api.rest_api.id
  resource_id          = aws_api_gateway_resource.resource[each.value].id
  http_method          = aws_api_gateway_method.options[each.value].http_method
  type                 = "MOCK"
  passthrough_behavior = "WHEN_NO_TEMPLATES"

  request_templates = {
    "application/json" = jsonencode(
        {
            statusCode = 200
        }
    )
  }
}

resource "aws_api_gateway_method_response" "mock" {
  for_each    = toset(local.resources)

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.resource[each.value].id
  http_method = aws_api_gateway_method.options[each.value].http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = true,
    "method.response.header.Access-Control-Allow-Methods"     = true,
    "method.response.header.Access-Control-Allow-Origin"      = true,
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "mock" {
  for_each    = toset(local.resources)

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.resource[each.value].id
  http_method = aws_api_gateway_method.options[each.value].http_method
  status_code = aws_api_gateway_method_response.mock[each.value].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = "'Authorization, Content-Type'",
    "method.response.header.Access-Control-Allow-Methods"     = "'GET,DELETE,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"      = contains(var.cors, each.value) ? "'https://${var.domain}'" : "'*'",
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

resource "aws_api_gateway_deployment" "production" {
  count = length(local.paths) > 0 ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name  = "production"
  stage_description = base64gzip(join("|", concat(local.paths, var.cors)))

  depends_on  = [
    aws_api_gateway_integration.integration, 
    aws_api_gateway_integration.mock, 
    aws_api_gateway_integration_response.mock,
    aws_api_gateway_method.method,
    aws_api_gateway_method.options,
    aws_api_gateway_method_response.mock,
    aws_lambda_permission.apigw_lambda
  ]

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "deploy_policy" {
  statement {
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction"
    ]

    resources = [
      "${join(":", slice(split(":", replace(aws_api_gateway_rest_api.rest_api.execution_arn, "execute-api", "lambda")), 0, 5))}:function:${var.api_name}_*"
    ]
  }
}

resource "aws_iam_user" "update_lambda" {
  name  = "${var.api_name}-lambda"
  path  = "/"
}

resource "aws_iam_access_key" "update_lambda" {
  user  = aws_iam_user.update_lambda.name
}

resource "aws_iam_user_policy" "update_lambda" {
  user   = aws_iam_user.update_lambda.name
  policy = data.aws_iam_policy_document.deploy_policy.json
}

data "aws_route53_zone" "zone" {
  name = var.domain
}

resource "aws_acm_certificate" "api" {
  domain_name       = "api.${var.domain}"
  validation_method = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "api_cert" {
  name    = tolist(aws_acm_certificate.api.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.api.domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.zone.id
  records = [tolist(aws_acm_certificate.api.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [aws_route53_record.api_cert.fqdn]
}

resource "aws_api_gateway_domain_name" "api" {
  certificate_arn = aws_acm_certificate_validation.api.certificate_arn
  domain_name     = "api.${var.domain}"
}

resource "aws_route53_record" "api" {
  name    = aws_api_gateway_domain_name.api.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.api.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api.cloudfront_zone_id
  }
}

resource "aws_api_gateway_base_path_mapping" "api" {
  count       = length(local.paths) > 0 ? 1 : 0
  api_id      = aws_api_gateway_rest_api.rest_api.id
  stage_name  = aws_api_gateway_deployment.production[0].stage_name
  domain_name = aws_api_gateway_domain_name.api.domain_name
}
