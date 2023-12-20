terraform {
    required_version = ">= 0.12"

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = ">= 3.24"
        }
    }
}

variable "aws_region" {
    type = map
    default = {
        dev = "us-east-1"
        prod = "eu-west-2"
    }
}

provider "aws" {
    region = var.aws_region[terraform.workspace]
}

data "archive_file" "myzip" {
    type = "zip"
    source_file = "main.py"
    output_path = "main.zip"
}

resource "aws_lambda_function" "mypython_lambda" {
    filename = "main.zip"
    function_name = "mypython_lambda_test_${terraform.workspace}"
    role = aws_iam_role.mypython_lambda_role.arn
    handler = "main.lambda_handler"
    runtime = "python3.9"
    source_code_hash = "data.archive_file.myzip.output_base64sha256"
}

resource "aws_iam_role" "mypython_lambda_role" {
    name = "mypython_role"
    
    assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
EOF
}

resource "aws_sqs_queue" "main_queue" {
    name = "my-main-queue-${terraform.workspace}"
    delay_seconds = 30
    max_message_size = 262144
}

resource "aws_sqs_queue" "dlq_queue" {
    name = "my-dlq-queue-${terraform.workspace}"
    delay_seconds = 30
    max_message_size = 262144
}

resource "aws_lambda_event_source_mapping" "sqs-lambda-trigger" {
    event_source_arn = aws_sqs_queue.main_queue.arn
    function_name = aws_lambda_function.mypython_lambda.arn
}