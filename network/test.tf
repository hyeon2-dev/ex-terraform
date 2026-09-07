# resource "aws_instance" "std19_ec2" {
#     count           = 2
#     subnet_id       = "subnet-0911ef33791cebe31"
#     ami             = "ami-096f5760b00bcd95c"
#     instance_type   = "t3.nano"
#     tags = {
#         Name = "test${count.index+1}-instance"
#     }
# }

# resource "aws_instance" "std19_ec2" {
#     for_each        = toset(["logs", "media", "backups"])
#     subnet_id       = "subnet-0911ef33791cebe31"
#     ami             = "ami-096f5760b00bcd95c"
#     instance_type   = "t3.nano"
#     tags = {
#         Name = "test-${each.key}-instance"
#     }
# }

# resource "aws_instance" "std19_ec2" {
#     for_each        = {
#         "a" = "logs"
#         "b" = "media"
#         "c" = "backups"
#     }
#     subnet_id       = "subnet-0911ef33791cebe31"
#     ami             = "ami-096f5760b00bcd95c"
#     instance_type   = "t3.nano"
#     tags = {
#         Name = "test-${each.key}-instance"
#     }
# }

# output "prt_instance" {
#     # value   = aws_instance.std19_ec2["media"].tags
#     # value = { for k, v in aws_instance.std19_ec2 : k => v.tags["Name"]}
#     value   = aws_instance.std19_ec2["b"].tags
# }