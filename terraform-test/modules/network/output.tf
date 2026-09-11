output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = {
    for key, subnet in aws_subnet.std19_private_subnet :
    key => subnet.id
  }
}

output "internal_web_sg_id" {
  value = aws_security_group.std19_internal_alb_sg.id
}