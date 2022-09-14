resource "aws_lambda_function" "example" {
  filename      = "lambda_function_name.zip"
  function_name = "lambda_function_name"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function_name.ocr_process"
  memory_size   = 2048
  timeout       = 120

  environment {
    variables = {
      S3_INPUTS_BUCKET  = "ocr-demo-inputs-tmp"
      S3_OUTPUTS_BUCKET = "ocr-demo-outputs-tmp"
    }
  }

  source_code_hash = filebase64sha256("lambda_function_name.zip")
  runtime          = "python3.9"

  file_system_config {
    arn              = aws_efs_access_point.access_point_for_lambda.arn
    local_mount_path = "/mnt/lambda_ocr_module"
  }

  vpc_config {
    subnet_ids         = [for k, v in aws_subnet.subnet_for_lambda : aws_subnet.subnet_for_lambda[k].id]
    security_group_ids = [aws_security_group.sg_for_lambda.id]
  }

  layers = [
    aws_lambda_layer_version.lambda_layer.arn,
    aws_lambda_layer_version.lambda_layer_two.arn
  ]

  depends_on = [aws_efs_mount_target.alpha]

}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]

  })

  managed_policy_arns = [
    aws_iam_policy.policy_one.arn,
    aws_iam_policy.lambda-ocr-module-logs-policy.arn,
    "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
    "arn:aws:iam::aws:policy/AWSLambdaExecute",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
  ]
}

resource "aws_iam_policy" "lambda-ocr-module-logs-policy" {
  name        = "lambda-ocr-module-logs-policy"
  description = "Logs policy for Lambda OCR Module"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:us-east-1:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:us-east-1:*:log-group:/aws/lambda/*:*"
      },
    ]
  })
}


resource "aws_iam_policy" "policy_one" {
  name        = "policy-test-one"
  description = "Test policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeInstances",
          "ec2:AttachNetworkInterface",
        ]
        Resource = "*"
      },
    ]
  })
}


resource "aws_security_group" "sg_for_lambda" {
  name        = "allow_nfs_port"
  description = "Allow NFS inbound traffic"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "allow_nfs"
  }
}

resource "aws_security_group_rule" "nfs_in" {
  type              = "ingress"
  description       = "NFS from VPC"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.main.cidr_block]
  security_group_id = aws_security_group.sg_for_lambda.id
}

resource "aws_security_group_rule" "public_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_for_lambda.id
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = "PDFNetPython3.zip"
  layer_name = "PDFNetPython3-test"

  compatible_runtimes      = ["python3.8", "python3.9"]
  compatible_architectures = ["x86_64"]
}

resource "aws_lambda_layer_version" "lambda_layer_two" {
  filename   = "OCRModuleLinux.zip"
  layer_name = "OCRModuleLinux-test"

  compatible_runtimes      = ["python3.8", "python3.9"]
  compatible_architectures = ["x86_64"]
}





resource "aws_api_gateway_rest_api" "lambda-ocr-module-rest" {

  name = "dev-pdftron-ocr-test"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}


























resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.lambda-ocr-module-rest.id
  parent_id   = aws_api_gateway_rest_api.lambda-ocr-module-rest.root_resource_id
  path_part   = "resource"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.lambda-ocr-module-rest.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda-ocr-module-intergration" {
  rest_api_id             = aws_api_gateway_rest_api.lambda-ocr-module-rest.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.example.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda-ocr-module-intergration
  ]
  rest_api_id = aws_api_gateway_rest_api.lambda-ocr-module-rest.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.resource.id,
      aws_api_gateway_method.method.id,
      aws_api_gateway_integration.lambda-ocr-module-intergration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
  stage_name = "test-stage"
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.lambda-ocr-module-rest.id
  stage_name    = "test-stage"

}



resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.lambda-ocr-module-rest.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = "200"
}


data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${local.region}:${local.account_id}:${aws_api_gateway_rest_api.lambda-ocr-module-rest.id}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource.resource.path}"
}


































