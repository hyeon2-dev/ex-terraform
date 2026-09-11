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

# ================================================================
# Public Subnet
# ================================================================
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
        "kubernetes.io/cluster/${local.tag_header}eks-cluster" = "shared"
        "kubernetes.io/role/elb" = "1" 
    })
}


# ================================================================
# Private Subnet
# ================================================================
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

# ================================================================
# Cluster Subnet
# ================================================================
resource "aws_subnet" "std19_cluster_subnet" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet if subnet.type == "cluster"
    }

    vpc_id                  = aws_vpc.this.id
    cidr_block              = each.value.cidr
    availability_zone       = each.value.az

    map_public_ip_on_launch = false
    enable_resource_name_dns_a_record_on_launch = true

    tags = merge({
        "Name" = "${local.tag_header}${each.key}-subnet"
        "Type" = each.value.type
        "kubernetes.io/cluster/${local.tag_header}eks-cluster" = "shared"
        "kubernetes.io/role/internal-elb" = "1"
    })
}

# ================================================================
# Gateway 생성
# ================================================================
# Internet Gateway 생성
resource "aws_internet_gateway" "std19_igw" {
    vpc_id = aws_vpc.this.id

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
    subnet_id     = aws_subnet.std19_public_subnet["public${split("-", local.az_names[0])[2]}"].id
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
    vpc_id = aws_vpc.this.id

    route {
        cidr_block = "0.0.0.0/0"    # 모든 목적지(인터넷)로 가는 트레픽은
        gateway_id = aws_internet_gateway.std19_igw.id
    }

    tags = {
        Name = "public-rt"
    }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "std19_public_rt_assoc" {
    for_each        		= aws_subnet.std19_public_subnet

    subnet_id           = each.value.id
    route_table_id      = aws_route_table.std19_public_rt.id
}

# Private Route Table생성 (2a, 2b, 2c)--------------------------------
resource "aws_route_table" "std19_private_rt" {
    for_each    = toset(local.az_names)
    vpc_id = aws_vpc.this.id

    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.std19_nat_gw.id
    }

    tags = {
        Name = "private${split("-", each.key)[2]}-rt"
    }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "std19_private_rt_assoc" {
    for_each    				= aws_subnet.std19_private_subnet
    subnet_id           = each.value.id
    route_table_id      = aws_route_table.std19_private_rt[each.value.availability_zone].id
}

# Cluster Route Table생성 -------------------------------------------
resource "aws_route_table" "std19_cluster_rt" {
    vpc_id = aws_vpc.this.id

    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.std19_nat_gw.id
    }

    tags = {
        Name = "cluster-rt"
    }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "std19_cluster_rt_assoc" {
    for_each    				= aws_subnet.std19_cluster_subnet
    subnet_id           = each.value.id
    route_table_id      = aws_route_table.std19_cluster_rt.id
}

# =================================================================================
# Security Group 생성
# =================================================================================
# SSH 접속용 Security Group 생성
resource "aws_security_group" "std19_ssh_sg" {
    name        = "${local.tag_header}ssh-sg"
    description = "Security group for SSH access"
    vpc_id      = aws_vpc.this.id

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
        Name = "internal-ssh-sg"
    }
}

# 웹 보안그룹(ALB용) 생성
resource "aws_security_group" "std19_external_alb_sg" {
    name        = "${local.tag_header}external-alb-sg"
    description = "Security group for web access"
    vpc_id      = aws_vpc.this.id

    
    dynamic "ingress" {
        for_each = [80, 443, 8000]
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
        Name = "external-alb-sg"
    }
}

resource "aws_security_group" "std19_internal_alb_sg" {
    name        = "${local.tag_header}internal-web-sg"
    description = "Security group for private web access"
    vpc_id      = aws_vpc.this.id

    # ingress {
    #     from_port   = 80
    #     to_port     = 80
    #     protocol    = "tcp"
    #     security_groups = [ aws_security_group.std19_external_alb_sg.id ]
    # }

    # ingress {
    #     from_port   = 443
    #     to_port     = 443
    #     protocol    = "tcp"
    #     security_groups = [ aws_security_group.std19_external_alb_sg.id ]
    # }

    dynamic "ingress" {
        for_each = [80, 443]
        content {
					from_port   = ingress.value
					to_port     = ingress.value
					protocol    = "tcp"
					security_groups = [ aws_security_group.std19_external_alb_sg.id ]
        }
    }    


    ingress {
        from_port   = 8000
        to_port     = 8000
        protocol    = "tcp"
        cidr_blocks = [ aws_vpc.this.cidr_block ]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    tags = {
        Name = "internal-alb-sg"
    }
}

# MYSQL 접속용 Security Group 생성
resource "aws_security_group" "std19_mysql_sg" {
    name        = "${local.tag_header}mysql-sg"
    description = "Security group for MYSQL access"
    vpc_id      = aws_vpc.this.id

    ingress {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = [ aws_vpc.this.cidr_block ]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "internal-mysql-sg"
    }
}

# EKS Security Group 생성
resource "aws_security_group" "std19_eks_sg" {
    name        = "${local.tag_header}eks-sg"
    description = "Security group for EKS access"
    vpc_id      = aws_vpc.this.id

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "cluster-sg"
    }
}

# EKS Node Security Group 생성
resource "aws_security_group" "std19_k8s_sg" {
    name        = "${local.tag_header}k8s-sg"
    description = "Security group for eks access"
    vpc_id      = aws_vpc.this.id

    dynamic "ingress" {
        for_each = [80, 443]
        content {
					from_port   = ingress.value
					to_port     = ingress.value
					protocol    = "tcp"
					security_groups = [ aws_security_group.std19_external_alb_sg.id ]
        }
    }

    ingress {
        from_port   = 10250
        to_port     = 10250
        protocol    = "tcp"
        security_groups = [ aws_security_group.std19_eks_sg.id ]
    }

    # 같은 보안 그룹을 사용하는 리소스 사이의 모든 통신 허용
    # TCP 10250도 포함됨
    ingress {
        description = "Allow communication between worker nodes"  # 워커노드간 통신을 위한 보안 규칙
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        self        = true  # 이 보안 그룹이 붙은 리소스끼리 통신을 허용
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "eks-node-sg"
    }
}

# ================================================================
# 클러스터 SG에 인바운드 규칙 추가
# 두 보안 그룹 생성 후 연결하므로 순환 참조를 피함
# ================================================================
# 워커 노드 -> 클러스터 API
resource "aws_security_group_rule" "std19_eks_from_nodes" {
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  # 출발지: 접속하는 워커 노드의 SG
  source_security_group_id = aws_security_group.std19_k8s_sg.id

  # 목적지: 규칙을 추가할 클러스터 SG
  security_group_id = aws_security_group.std19_eks_sg.id
}

# 사무실 -> 클러스터 private endpoint
resource "aws_security_group_rule" "std19_eks_from_office" {
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  # 출발지: 사무실 공인 IP 범위
  cidr_blocks = [ "0.0.0.0/0"]

  # 목적지: 규칙을 추가할 클러스터 SG
  security_group_id = aws_security_group.std19_eks_sg.id
}