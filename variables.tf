variable "infra_env" {
  type        = string
  description = "infrastructure environment"
}
variable "public_subnet_numbers" {
  type        = map(number)
  description = "Map of AZ"
  default = {
    "us-east-1a" = 1
    "us-east-1b" = 2
    "us-east-1c" = 3
  }
}

variable "region_number" {
  default = {
    us-east-1 = 1
    us-east-2 = 2
  }
}

variable "az_number" {
  default = {
    a = 1
    b = 2
    c = 3
    d = 4
    e = 5
    f = 6
  }
}

data "aws_availability_zone" "example" {
  name = "us-east-1a"
}
