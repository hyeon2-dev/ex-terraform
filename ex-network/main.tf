resource "aws_vpc" "std19_lab_vpc" {
    cidr_block = "10.0.0.0/16"  # 이 네트워크가 사용할 IP 주소 범위
    enable_dns_hostnames = true
    enable_dns_support = true
    instance_tenancy = "default"

    tags = {
        Name = "std19-lab-vpc"
    }
}

# ================================================================
# Public Subnet 생성
# ================================================================
resource "aws_subnet" "std19_public_subnet" {
    for_each                = toset(local.azs)
    # count                   = length(local.azs)
    vpc_id                  = aws_vpc.std19_lab_vpc.id
    cidr_block              = var.subnet_cidr[0][each.key]
    availability_zone       = each.key

    # Public Subnet 설정에 사용
    # map_public_ip_on_launch = (var.subnet_type[0] == "public" ? true : false)
    map_public_ip_on_launch = true
    enable_resource_name_dns_a_record_on_launch = true


    tags = {
        Name = "${local.tag_header}public-${split("-", each.key)[length(split("-", each.key))-1]}-subnet"
        "kubernetes.io/cluster/${local.tag_header}eks-cluster" = "shared"
        "kubernetes.io/role/elb" = "1"   
    }
}

# ================================================================
# Private Subnet 생성
# ================================================================
resource "aws_subnet" "std19_private_subnet" {
    for_each                = toset(local.azs)
    # count                   = length(local.azs)
    vpc_id                  = aws_vpc.std19_lab_vpc.id
    cidr_block              = var.subnet_cidr[1][each.key]
    availability_zone       = each.key

    tags = {
        Name = "${local.tag_header}private-${each.key}-subnet"
        "kubernetes.io/cluster/${local.tag_header}eks-cluster" = "shared"
        "kubernetes.io/role/internal-elb" = "1"
    }
}
# ================================================================
# Gateway 생성
# ================================================================
# Internet Gateway 생성
resource "aws_internet_gateway" "std19_igw" {
    vpc_id = aws_vpc.std19_lab_vpc.id

    tags = {
        Name = "std19-igw"
    }
}

# NAT Gateway 생성을 위한 EIP 생성
resource "aws_eip" "std19_nat_eip" {
    domain = "vpc"  # VPC용 EIP 생성, std19_nat_eip의 사용범위를 VPC로 제한

    tags = {
        Name = "std19-nat-eip"
    }
}

# NAT Gateway 생성
resource "aws_nat_gateway" "std19_nat_gw" {
    allocation_id = aws_eip.std19_nat_eip.id
    # NAT Gateway를 생성할 Public Subnet 지정
    subnet_id     = aws_subnet.std19_public_subnet[local.azs[0]].id
    # 인터넷 게이트웨이를 먼저 생성(완료)되면 이후 NAT Gateway를 생성하도록 의존성 설정
    depends_on =   [
        aws_internet_gateway.std19_igw
    ]
    tags = {
        Name = "std19-nat-gw"
    }
}

# ================================================================
# Route Table 생성
# ================================================================
# Public Route Table생성 -----------------------------------
resource "aws_route_table" "std19_public_rt" {
    vpc_id = aws_vpc.std19_lab_vpc.id

    # 아래의 코드를 사용하면 3. 라우팅부분을 빼도 된다. 
    route {
        cidr_block = "0.0.0.0/0"    # 모든 목적지(인터넷)로 가는 트레픽은
        gateway_id = aws_internet_gateway.std19_igw.id
    }

    tags = {
        Name = "${local.tag_header}public-rt"
    }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "std19_public_rt_assoc" {
    for_each        = toset(local.azs)

    subnet_id           = aws_subnet.std19_public_subnet[each.key].id
    route_table_id      = aws_route_table.std19_public_rt.id
}
# -------------------------------------------------------------------------

# Private Route Table생성 (2a, 2b, 2c, 2d)--------------------------------
resource "aws_route_table" "std19_private_rt" {
    for_each    = toset(local.azs)
    vpc_id = aws_vpc.std19_lab_vpc.id

    tags = {
        Name = "${local.tag_header}private-rt"
    }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "std19_private_rt_assoc" {
    for_each    = toset(local.azs)
    subnet_id           = aws_subnet.std19_private_subnet[each.key].id
    route_table_id      = aws_route_table.std19_private_rt[each.key].id
}

# 3. 라우팅
resource "aws_route" "std19_private_rt_route" {
    for_each    = toset(local.azs)
    route_table_id          = aws_route_table.std19_private_rt[each.key].id
    destination_cidr_block  = "0.0.0.0/0"
    nat_gateway_id          = aws_nat_gateway.std19_nat_gw.id
}

# =================================================================================
# Security Group 생성
# =================================================================================
# SSH 접속용 Security Group 생성
resource "aws_security_group" "std19_ssh_sg" {
    name        = "${local.tag_header}ssh-sg"
    description = "Security group for SSH access"
    vpc_id      = aws_vpc.std19_lab_vpc.id

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}ssh-sg"
    }
}

# MYSQL 접속용 Security Group 생성
resource "aws_security_group" "std19_mysql_sg" {
    name        = "${local.tag_header}mysql-sg"
    description = "Security group for MYSQL access"
    vpc_id      = aws_vpc.std19_lab_vpc.id

    ingress {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}mysql-sg"
    }
}

# 웹 보안그룹(ALB용) 생성
resource "aws_security_group" "std19_external_alb_sg" {
    name        = "${local.tag_header}external-alb-sg"
    description = "Security group for web access"
    vpc_id      = aws_vpc.std19_lab_vpc.id

    
    dynamic "ingress" {
        for_each = [80, 443]
        content {
        from_port   = ingress.value
        to_port     = ingress.value
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        }
    }    

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}external-alb-sg"
    }
}

# =================== 프라이빗 웹 인스턴스용 보안그룹 ===============================
resource "aws_security_group" "std19_internal_alb_sg" {
    name        = "${local.tag_header}internal-web-sg"
    description = "Security group for private web access"
    vpc_id      = aws_vpc.std19_lab_vpc.id

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    tags = {
        Name = "${local.tag_header}internal-alb-sg"
    }
}

# 보안그룹 규칙 추가: 외부 ALB에서 내부 ALB로의 트래픽 허용
resource "aws_security_group_rule" "std19_internal_alb_rule" {
    type                        = "ingress"
    from_port                   = 80
    to_port                     = 80
    protocol                    = "tcp"
    # 규칙을 추가할 보안 그룹의 아이디
    source_security_group_id    = aws_security_group.std19_external_alb_sg.id
    # 소스로 어떤 보안 그룹을 추가할지 추가할 보안그룹의 아이디 지정
    security_group_id           = aws_security_group.std19_internal_alb_sg.id  
}


# ===========================================================================
# NACL
resource "aws_network_acl" "std19_nacl" {
    vpc_id = aws_vpc.std19_lab_vpc.id   # VPC-id

    ingress {
        rule_no     = 100   # rule_no는 ingress에서 중복되지 않게 작성
        protocol    = "tcp"
        action      = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 80
        to_port     = 80
    }

    ingress {
        rule_no     = 110   # rule_no는 ingress에서 중복되지 않게 작성
        protocol    = "tcp"
        action      = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 443
        to_port     = 443
    }

    ingress {
        rule_no     = 120   # rule_no는 ingress에서 중복되지 않게 작성
        protocol    = "tcp"
        action      = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 22
        to_port     = 22
    }

    # 응답 임시포트(작성을안할경우 초기 응답 불가 상태로 포트 통신이 되지 않음)
    ingress {
        rule_no     = 130   # rule_no는 ingress에서 중복되지 않게 작성
        protocol    = "tcp"
        action      = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 1024
        to_port     = 65535
    }

    egress {
        rule_no     = 100   # rule_no는 egress에서 중복되지 않게 작성
        protocol    = "-1"
        action      = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 0
        to_port     = 0
    }
    
    tags = {
        Name = "std19-nacl"
    }
}

# 서브넷 연결
resource "aws_network_acl_association" "std19-nacl-assoc" {
    subnet_id = aws_subnet.std19_public_subnet[local.azs[0]].id    # subnet-id
    network_acl_id = aws_network_acl.std19_nacl.id      # network-acl-id
}