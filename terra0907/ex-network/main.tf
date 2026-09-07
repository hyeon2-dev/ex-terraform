resource "aws_vpc" "std19_lab_vpc" {
    cidr_block = "10.0.0.0/16"  # 이 네트워크가 사용할 IP 주소 범위
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
        Name = "std19-lab-vpc"
    }
}