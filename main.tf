terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.38.0"
    }
  }

  required_version = ">= 1.2.5"
}

provider "aws" {
  region = local.region
}

locals {
  name            = "cw-alarm"
  environment     = "dev"
  region          = "eu-central-1"
}


resource "aws_iam_role" "sns" {
  name = "${local.name}-sns-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "sns.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${local.name}-sns-role"
    Environment = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "sns-AmazonSNSRole" {
  role       = aws_iam_role.sns.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSNSRole"
}

resource "aws_iam_role" "lambda" {
  name = "${local.name}-lambda-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda-AWSLambdaBasicExecutionRole" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# resource "aws_cloudwatch_log_group" "sns" {
#   name = "/${local.name}-logs"

#   tags = {
#     Name        = "/${local.name}-logs"
#     Environment = local.environment
#   }
# }

resource "aws_sns_topic" "main" {
  name = local.name

  lambda_success_feedback_role_arn = aws_iam_role.sns.arn
  lambda_failure_feedback_role_arn = aws_iam_role.sns.arn
  lambda_success_feedback_sample_rate = 100

  tags = {
    Name        = "${local.name}-sns-topic"
    Environment = local.environment
  }
}

data "archive_file" "app" {
  type        = "zip"
  source_dir  = "${path.module}/app"
  output_path = "${path.module}/app.zip"
}

resource "aws_lambda_function" "main" {
  function_name    = "${local.name}-function"
  filename         = "${path.module}/app.zip"
  source_code_hash = data.archive_file.app.output_base64sha256
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.9"
  handler          = "lambda_function.lambda_handler"
  timeout          = 10
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.main.arn
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.main.arn
}