provider "aws" {
  region = "us-west-1"  # Defina a região apropriada
}

# Cluster do Amazon DocumentDB
resource "aws_docdb_cluster" "docdb_cluster" {
  cluster_identifier      = "documentdb-cluster"
  master_username         = var.db_user
  master_password         = var.db_password
  skip_final_snapshot     = true
}

resource "aws_docdb_cluster_instance" "docdb_instance" {
  count            = 2
  identifier       = "docdb-instance-${count.index}"
  cluster_identifier = aws_docdb_cluster.docdb_cluster.id
  instance_class   = "db.r5.large"  # Ajuste o tipo da instância conforme necessário
  apply_immediately = true
}

# Subnet Group para o DocumentDB
resource "aws_docdb_subnet_group" "docdb_subnet_group" {
  name       = "my-docdb-subnet-group"
  subnet_ids = aws_subnet.my_subnet[*].id
}

# Função Lambda
resource "aws_lambda_function" "functionValidaCpf" {
  function_name = "cpf-verification-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.lambdaHandler"   # Handler para o Node.js
  runtime       = "nodejs20.x"

  filename      = "lambda.zip"            # O arquivo ZIP com seu código
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      DOCUMENTDB_URI = aws_docdb_cluster.docdb_cluster.endpoint
      DB_NAME        = var.db_name
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.my_subnet[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_logging]
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

# Permissões de Log para a Lambda (CloudWatch)
resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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

resource "aws_subnet" "my_subnet" {
  count = 2
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.main_vpc.cidr_block, 8, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Subnet para o DocumentDB
resource "aws_docdb_subnet_group" "docdb_subnet_group" {
  name       = "my-docdb-subnet-group"
  subnet_ids = aws_subnet.my_subnet[*].id
}
