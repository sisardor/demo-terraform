output "vpc_public_subnets" {
  value = {
    for subnet in aws_subnet.subnet_for_lambda : subnet.id => subnet.cidr_block
  }
}
