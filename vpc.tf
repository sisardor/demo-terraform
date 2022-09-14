resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/17"
  instance_tenancy = "default"
  tags = {
    Name = "vpc.main.lambda-ocr-module"
  }
}

resource "aws_subnet" "subnet_for_lambda" {
  for_each          = var.public_subnet_numbers
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 4, each.value)
  availability_zone = each.key
  tags = {
    Name      = "lambda-${var.infra_env}-public-subnet"
    Role      = "public"
    ManagedBy = "terraform"
    Subnet    = "${each.key}-${each.value}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tabs = {
    Name = "gw.lambda-ocr-module"
  }
}
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = ""
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "rt.lambda-ocr-module"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
}



resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.subnet_for_lambda.id

}
