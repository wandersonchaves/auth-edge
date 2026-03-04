terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "auth-edge"
}

# --- Cognito ---
resource "aws_cognito_user_pool" "pool" {
  name = "${var.project_name}-user-pool"

  password_policy {
    minimum_length = 8
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 5
      max_length = 100
    }
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.pool.id
  generate_secret = false
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_group" "user" {
  name         = "user"
  user_pool_id = aws_cognito_user_pool.pool.id
}

# --- DynamoDB ---
resource "aws_dynamodb_table" "audit_logs" {
  name           = "${var.project_name}-audit-logs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "PK"
  range_key      = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

# --- IAM Role for Lambdas ---
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamo" {
  name = "DynamoDBWrite"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["dynamodb:PutItem"]
      Effect = "Allow"
      Resource = aws_dynamodb_table.audit_logs.arn
    }]
  })
}

# --- Lambdas ---
resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-api"
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "../../../../apps/api/dist/bundle.zip"
  source_code_hash = filebase64sha256("../../../../apps/api/dist/bundle.zip")

  environment {
    variables = {
      AUDIT_TABLE_NAME = aws_dynamodb_table.audit_logs.name
    }
  }
}

resource "aws_lambda_function" "authorizer" {
  function_name = "${var.project_name}-authorizer"
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "../../../../apps/authorizer/dist/bundle.zip"
  source_code_hash = filebase64sha256("../../../../apps/authorizer/dist/bundle.zip")

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.pool.id
      CLIENT_ID    = aws_cognito_user_pool_client.client.id
      AUDIT_TABLE_NAME = aws_dynamodb_table.audit_logs.name
    }
  }
}

# CloudWatch Log Groups (7 days retention)
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "auth_logs" {
  name              = "/aws/lambda/${aws_lambda_function.authorizer.function_name}"
  retention_in_days = 7
}

# --- API Gateway HTTP ---
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-gateway"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_authorizer" "lambda_auth" {
  api_id           = aws_apigatewayv2_api.http_api.id
  authorizer_type  = "REQUEST"
  authorizer_uri   = aws_lambda_function.authorizer.invoke_arn
  identity_sources = ["$request.header.Authorization"]
  name             = "lambda-authorizer"
  authorizer_payload_format_version = "2.0"
  enable_simple_responses = true
}

resource "aws_apigatewayv2_integration" "api_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

# Rotas
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.api_integration.id}"
}

resource "aws_apigatewayv2_route" "me" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "GET /me"
  target             = "integrations/${aws_apigatewayv2_integration.api_integration.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda_auth.id
}

resource "aws_apigatewayv2_route" "admin" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "GET /admin"
  target             = "integrations/${aws_apigatewayv2_integration.api_integration.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda_auth.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Permissões Gateway -> Lambda
resource "aws_lambda_permission" "apigw_api" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_auth" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "api_endpoint" { value = aws_apigatewayv2_api.http_api.api_endpoint }
output "user_pool_id" { value = aws_cognito_user_pool.pool.id }
output "app_client_id" { value = aws_cognito_user_pool_client.client.id }
output "region" { value = var.aws_region }
