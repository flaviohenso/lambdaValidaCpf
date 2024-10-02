provider "aws" {
  region = "us-east-1"  # Defina a região apropriada
  profile = "my-profile"
}

# Função Lambda
resource "aws_lambda_function" "functionValidaCpf" {
  function_name = "cpf-verification-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.handler"   # Handler para o Node.js
  runtime       = "nodejs20.x"

  filename      = "lambda.zip"            # O arquivo ZIP com seu código
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      DOCUMENTDB_URI = "mongodb://fiap:qZ7zqQn1j4QVMd9i@mongodb-fiap-tech-challenge.cluster-cpsw6q668tdw.us-east-1.docdb.amazonaws.com:27017/fiap?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
      DB_NAME        = var.db_name
    }
  }

  vpc_config {
    subnet_ids         = ["subnet-0115b6d08158577bf", "subnet-0754183aca138c7aa"]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# IAM Role para a Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Política IAM com permissões adicionais para Lambda em VPC
resource "aws_iam_policy" "lambda_vpc_policy" {
  name        = "lambda-vpc-policy"
  description = "Permissões necessárias para a Lambda funcionar dentro de uma VPC"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Anexar a política à Role
resource "aws_iam_role_policy_attachment" "lambda_vpc_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_vpc_policy.arn
}

# Configuração da VPC e Subnets
resource "aws_security_group" "lambda_sg" {
  name_prefix = "lambda-sg"

  ingress {
    from_port   = 27017   # Porta do DocumentDB (MongoDB)
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Altere conforme a necessidade de segurança
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}
