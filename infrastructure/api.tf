# 1. DynamoDB Table (The Database)
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

  # FIX: Use default AWS encryption (CKV_AWS_119)
  server_side_encryption {
    enabled = true
    # We use the default AWS Owned Key (free) instead of a Customer Managed Key ($$)
    # checkov:skip=CKV_AWS_119: "Using default AWS owned CMK to save costs for resume project"
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

  # SKIP: VPC requires NAT Gateway which costs ~$30/mo (CKV_AWS_117)
  # checkov:skip=CKV_AWS_117: "Skipping VPC to avoid NAT Gateway costs for free-tier project"

  # SKIP: DLQ is overkill for synchronous API Gateway integration (CKV_AWS_116)
  # checkov:skip=CKV_AWS_116: "DLQ not required for simple synchronous API invocation"

  # SKIP: Code Signing is complex overkill for this project (CKV_AWS_272)
  # checkov:skip=CKV_AWS_272: "Code signing is overkill for personal project"

  # SKIP: KMS Customer keys cost money (CKV_AWS_173)
  # checkov:skip=CKV_AWS_173: "Using default encryption to save costs"
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
    allow_origins = ["*"]
    allow_methods = ["GET"]
    allow_headers = ["Content-Type"]
  }
}

# FIX: create a log group for API Gateway (CKV_AWS_76)
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gateway/${aws_apigatewayv2_api.visitor_api.name}"

  retention_in_days = 7
  # checkov:skip=CKV_AWS_338: "Retention of 7 days is sufficient for this project"
  # checkov:skip=CKV_AWS_158: "KMS encryption for logs costs extra"
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
  api_id    = aws_apigatewayv2_api.visitor_api.id
  route_key = "GET /visitor-count"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  
  # ADD THIS LINE: Explicitly tell AWS this is a public API
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_api.execution_arn}/*/*/visitor-count"
}