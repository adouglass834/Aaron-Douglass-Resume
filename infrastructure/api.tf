# 1. DynamoDB Table (The Database)
resource "aws_kms_key" "dynamodb_key" {
  description             = "KMS key for DynamoDB encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow DynamoDB to use the key"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "dynamodb.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "visitor-counter-dynamodb-key"
    Environment = "production"
  }
}

resource "aws_kms_alias" "dynamodb_key_alias" {
  name          = "alias/visitor-counter-dynamodb"
  target_key_id = aws_kms_key.dynamodb_key.key_id
}

data "aws_kms_alias" "lambda" {
  name = "alias/aws/lambda"
}

data "aws_kms_alias" "logs" {
  name = "alias/aws/logs"
}

variable "allowed_cors_origin" {
  description = "Allowed CORS origin for visitor API"
  type        = string
  default     = "https://example.com"
}

resource "aws_dynamodb_table" "visitor_counter" {
  name           = "visitor-counter-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # FIX: Enable Point-in-Time Recovery (CKV_AWS_28)
  point_in_time_recovery {
    enabled = true
  }

  # FIX: Use customer-managed KMS key (CKV_AWS_119)
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }
}

resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "visitor-counter-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_signer_signing_profile" "lambda_signer" {
  name_prefix = "visitor-counter-signer"
  platform_id = "AWSLambda-SHA384-ECDSA"
}

resource "aws_lambda_code_signing_config" "visitor_counter" {
  description = "Code signing config for visitor counter lambda"

  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.lambda_signer.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Warn"
  }
}

# 2. Archive the Python File
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "counter.py"
  output_path = "counter.zip"
}

# 3. Lambda Function
resource "aws_lambda_function" "visitor_counter" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "visitor-counter-func"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "counter.lambda_handler"
  
  # FIX: Update runtime to a newer version (CKV_AWS_363)
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256


  # FIX: Enable X-Ray Tracing (CKV_AWS_50)
  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_counter.name
    }
  }

  kms_key_arn = data.aws_kms_alias.lambda.target_key_arn

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  code_signing_config_arn = aws_lambda_code_signing_config.visitor_counter.arn

  # FIX: Set concurrent execution limit (CKV_AWS_115)
  reserved_concurrent_executions = 10

  # SKIP: VPC requires NAT Gateway which costs ~$30/mo (CKV_AWS_117)
  # checkov:skip=CKV_AWS_117: "Skipping VPC to avoid NAT Gateway costs for free-tier project"
}

# 4. IAM Role
resource "aws_iam_role" "lambda_exec" {
  name = "visitor-counter-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Allow Lambda to write to DynamoDB and log to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# FIX: Add X-Ray permissions since we enabled tracing
resource "aws_iam_role_policy_attachment" "xray_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_iam_role_policy" "dynamodb_access" {
  name = "dynamodb-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:UpdateItem", "dynamodb:GetItem"]
      Resource = aws_dynamodb_table.visitor_counter.arn
    }]
  })
}

# 5. API Gateway
resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "visitor-counter-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = [var.allowed_cors_origin]
    allow_methods = ["GET"]
    allow_headers = ["Content-Type"]
  }
}

# FIX: create a log group for API Gateway (CKV_AWS_76)
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gateway/${aws_apigatewayv2_api.visitor_api.name}"

  retention_in_days = 365
  kms_key_id        = aws_kms_key.cloudwatch_logs_key.arn
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.visitor_api.id
  name        = "prod"
  auto_deploy = true

  # FIX: Enable Access Logging (CKV_AWS_76)
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format          = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.visitor_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.visitor_counter.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id             = aws_apigatewayv2_api.visitor_api.id
  route_key          = "GET /visitor-count"
  target             = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_api.execution_arn}/*/*/visitor-count"
}