# CLOUD-28 compute (layer 1, destroyed after every session).
# The Terraform twin of the console build of 12 Oct 2026: a Lambda function behind an API Gateway
# HTTP API. Compute on AWS is serverless because the account has no free EC2 hours.
# Tags: lab and layer come from the provider default_tags; domain is set per resource. The HTTP API
# and its stage take tags here, which the console did not offer (they were set with the CLI).
#
# Differences from the console build, on purpose:
#   - The log group is declared here with 7-day retention. In the console Lambda created it by
#     itself with retention "never expires", outside any plan, and deleting the function left it behind.
#   - The execution role uses AWS's managed AWSLambdaBasicExecutionRole instead of the policy the
#     console generates for one function.
#   - The stage is throttled (5 requests a second, burst 10) because the route is open to the internet
#     and the URL stays public while it exists.
#   - The default name ends in -tf so it can exist next to the console-built cloud-lab-hello.

variable "lambda_name" {
  description = "Function name. Ends in -tf so it does not collide with the console-built cloud-lab-hello and its log group while that one still exists."
  type        = string
  default     = "cloud-lab-hello-tf"
}

variable "lambda_runtime" {
  description = "Python runtime of the function."
  type        = string
  default     = "python3.13"
}

data "archive_file" "hello" {
  type        = "zip"
  source_file = "${path.module}/lambda/hello.py"
  output_path = "${path.module}/.build/hello.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "hello" {
  name               = "${var.lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = {
    domain = "compute"
  }
}

resource "aws_iam_role_policy_attachment" "hello_logs" {
  role       = aws_iam_role.hello.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Declared so that destroy removes it and so the retention is not "never expires".
resource "aws_cloudwatch_log_group" "hello" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 7

  tags = {
    domain = "compute"
  }
}

resource "aws_lambda_function" "hello" {
  function_name    = var.lambda_name
  role             = aws_iam_role.hello.arn
  handler          = "hello.handler"
  runtime          = var.lambda_runtime
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 3
  filename         = data.archive_file.hello.output_path
  source_code_hash = data.archive_file.hello.output_base64sha256

  tags = {
    domain = "compute"
  }

  depends_on = [
    aws_cloudwatch_log_group.hello,
    aws_iam_role_policy_attachment.hello_logs,
  ]
}

resource "aws_apigatewayv2_api" "hello" {
  name          = "${var.lambda_name}-API"
  protocol_type = "HTTP"

  tags = {
    domain = "compute"
  }
}

resource "aws_apigatewayv2_integration" "hello" {
  api_id                 = aws_apigatewayv2_api.hello.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.hello.invoke_arn
  payload_format_version = "2.0"
}

# No authorization on purpose: this is the open route the exercise measures.
resource "aws_apigatewayv2_route" "hello" {
  api_id    = aws_apigatewayv2_api.hello.id
  route_key = "ANY /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello.id}"
}

# Access logging and detailed metrics stay off: both would add CloudWatch charges.
resource "aws_apigatewayv2_stage" "hello" {
  api_id      = aws_apigatewayv2_api.hello.id
  name        = "default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
  }

  tags = {
    domain = "compute"
  }
}

resource "aws_lambda_permission" "hello_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.hello.execution_arn}/*/*"
}
