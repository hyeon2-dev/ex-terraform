# VPC
resource "aws_vpc" "this" {
    cidr_block = "10.0.0.0/16"  # 이 네트워크가 사용할 IP 주소 범위
    enable_dns_hostnames = true
    enable_dns_support = true
    # instance_tenancy = "default"

    tags = {
        Name = "${local.tag_header}vpc"
    }
}

# Public Subnet
resource "aws_subnet" "std19_public_subnet" {
    # Public 블록의 for_each
    for_each = {
        for key, subnet in var.subnet_map :
        key => subnet if subnet.type == "public"
    }

    vpc_id                  = aws_vpc.this.id
    cidr_block              = each.value.cidr
    availability_zone       = each.value.az
  
    map_public_ip_on_launch = each.value.type == "public" ? true : false
    enable_resource_name_dns_a_record_on_launch = true

    tags = merge({
        "Name" = "${local.tag_header}${each.key}-subnet"
        "Type" = each.value.type
    })
}

# Private Subnet
resource "aws_subnet" "std19_private_subnet" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet if subnet.type == "private"
    }

    vpc_id                  = aws_vpc.this.id
    cidr_block              = each.value.cidr
    availability_zone       = each.value.az

    map_public_ip_on_launch = false
    enable_resource_name_dns_a_record_on_launch = true

    tags = merge({
        "Name" = "${local.tag_header}${each.key}-subnet"
        "Type" = each.value.type
    })
}

# output "vpc_id" {
#     value   = aws_vpc.this.id
# }