# terraform init: 테라폼 초기화
# terraform plan: 테라폼을 통해 배포 가능한지 확인(--out=filename옵션을 통해 plan 파일 생성 가능)
# terraform apply: 테라폼을 통해 배포(--auto-approve 옵션을 통해 자동 승인 가능)
# terraform destroy: 테라폼을 통해 배포된 리소스 삭제(--auto-approve 옵션을 통해 자동 승인 가능)

resource "aws_vpc" "std19_vpc" {
    cidr_block              = var.vpc_cidr
    instance_tenancy        = "default"
    enable_dns_support      = true
    enable_dns_hostnames    = true
    tags                    = {
        Name = "${local.tag_header}vpc"
    }
}

# ================================================================
# Public Subnet 생성
# ================================================================
resource "aws_subnet" "std19_public_subnet" {
    for_each                = toset(local.azs)
    # count                   = length(local.azs)
    vpc_id                  = aws_vpc.std19_vpc.id
    cidr_block              = var.subnet_cidr[0][each.key]
    availability_zone       = each.key

    # Public Subnet 설정에 사용
    # map_public_ip_on_launch = (var.subnet_type[0] == "public" ? true : false)
    map_public_ip_on_launch = true
    enable_resource_name_dns_a_record_on_launch = true


    tags = {
        Name = "${local.tag_header}public-${split("-", each.key)[length(split("-", each.key))-1]}-subnet"
    }
}

# ================================================================
# Private Subnet 생성
# ================================================================
resource "aws_subnet" "std19_private_subnet" {
    for_each                = toset(local.azs)
    # count                   = length(local.azs)
    vpc_id                  = aws_vpc.std19_vpc.id
    cidr_block              = var.subnet_cidr[1][each.key]
    availability_zone       = each.key

    tags = {
        Name = "${local.tag_header}private-${each.key}-subnet"
    }
}

# ================================================================
# Gateway 생성
# ================================================================
# Internet Gateway 생성
resource "aws_internet_gateway" "std19_igw" {
    vpc_id = aws_vpc.std19_vpc.id

    tags = {
        Name = "${local.tag_header}igw"
    }
}

# NAT Gateway 생성을 위한 EIP 생성
resource "aws_eip" "std19_nat_eip" {
    domain = "vpc"  # VPC용 EIP 생성, std19_nat_eip의 사용범위를 VPC로 제한

    tags = {
        Name = "${local.tag_header}nat-eip"
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
        Name = "${local.tag_header}nat-gw"
    }
}

# ================================================================
# Route Table 생성
# ================================================================
# Public Route Table생성 -----------------------------------
resource "aws_route_table" "std19_public_rt" {
    vpc_id = aws_vpc.std19_vpc.id

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
# resource "aws_route_table_association" "std19_public2a_rt_assoc" {
#     subnet_id           = aws_subnet.std19_public2a_subnet.id
#     route_table_id      = aws_route_table.std19_public_rt.id
# }

# 3. 라우팅
resource "aws_route" "std19_public_rt_route" {
    route_table_id          = aws_route_table.std19_public_rt.id
    destination_cidr_block  = "0.0.0.0/0"
    gateway_id              = aws_internet_gateway.std19_igw.id
}
# -------------------------------------------------------------------------

# Private Route Table생성 (2a, 2b, 2c, 2d)--------------------------------
resource "aws_route_table" "std19_private_rt" {
    for_each    = toset(local.azs)
    vpc_id = aws_vpc.std19_vpc.id

    tags = {
        Name = "${local.tag_header}private-${each.key}-rt"
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
    vpc_id      = aws_vpc.std19_vpc.id

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
    vpc_id      = aws_vpc.std19_vpc.id

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
    vpc_id      = aws_vpc.std19_vpc.id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 443
        to_port     = 443
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
        Name = "${local.tag_header}external-alb-sg"
    }
}

# =================== 프라이빗 웹 인스턴스용 보안그룹 ===============================
resource "aws_security_group" "std19_internal_alb_sg" {
    name        = "${local.tag_header}internal-web-sg"
    description = "Security group for private web access"
    vpc_id      = aws_vpc.std19_vpc.id

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

# FastAPI 접속용 Security Group 생성
resource "aws_security_group" "std19_fastapi_sg" {
    name        = "${local.tag_header}fastapi-sg"
    description = "Security group for fastapi access"
    vpc_id      = aws_vpc.std19_vpc.id

    ingress {
        from_port   = 8000
        to_port     = 8000
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
        Name = "${local.tag_header}fastapi-sg"
    }
}


# ============================================================================
# 테라폼은 선언형 언어, IF문이 없다.
# if문을 대체하는 3항 연산자를 통해 간단한 제어만 가능
# [일반 삼항연산자] - 조건 ? 조건이 참일때의 값 : 조건이 거짓일때의 값
# [다중 삼항연산자] - 조건1 ? 조건1이 참일때의 값 : (조건2? 조건2가 참일때의 값 : 조건2가 거짓일때의 값)
locals {
    instance_chk = true
}

resource "aws_instance" "std19_instance" {
    count           = local.instance_chk ? 1 : 0
    ami             = "ami-096f5760b00bcd95c"
    subnet_id       = aws_subnet.std19_public_subnet[local.azs[0]].id
    instance_type   = "t3.micro"

    tags = {
        Name = "std19-instance-${count.index + 1}"
    }
}


# =============================================================================
# 중첩 삼항 연산자
locals {
    instance_type = "default"   # "nano, micro, small"
}

resource "aws_instance" "std19_ec2" {
    ami             = "ami-096f5760b00bcd95c"
    subnet_id       = aws_subnet.std19_public_subnet[local.azs[0]].id
    instance_type   = local.instance_type == "default" ? "t3.nano" : (
                      local.instance_type == "micro" ? "t3.micro" : "t3.small" )

    tags = {
        Name = "std19-instance"
    }
}

# ============================================================================
# 문자열 함수
output "zfunc_string_upper" {
    value = upper("abcd")   # 대문자로 변환
}

output "zfunc_string_lower" {
    value = lower("aBCd")   # 소문자로 변환
}

output "zfunc_string_replace" {
    value = replace("abcdb", "bc", "K")   # 찾은 문자열 모두 치환
}

# 문자열 나누기
# 전체 문자열에서 특정 문자를 기준으로 리스트로 변환
output "zfunc_string_split" {
    value = split("-", "us-west-2a")[length(split("-", "us-west-2a"))-1]
}

# 리스트의 각 요소를 지정 문자를 이용하여 연결
output "zfunc_string_join" {
    value = join("*", split("-", "us-west-2a"))
}

# for 표현식
output "for" {
    value = [for num in [2, 4, 5, 65, 78] : num*num if num%2 == 0]
}
