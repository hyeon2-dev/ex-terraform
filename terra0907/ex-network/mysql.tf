# mysql.tf
# =============================================================================
# 서브넷 그룹 생성
# =============================================================================
data "aws_subnets" "subnet_ids" {
    # filter {
    #     name    = "vpc-id"
    #     value  = [ "vpc_id" ]
    # }

    filter {
        name    = "tag:Name"
        values  = [
            "std19-private-us-west-2a-subnet",
            "std19-private-us-west-2b-subnet",
            "std19-private-us-west-2c-subnet",
            "std19-private-us-west-2d-subnet"
        ]
    }
}

resource "aws_db_subnet_group" "std19_db_subnet_group" {
    name        = "std19-db-subnet-group"
    # subnet_ids = [
    #     aws_subnet.std19_private_subnet[local.azs[0]].id,
    #     aws_subnet.std19_private_subnet[local.azs[1]].id,
    #     aws_subnet.std19_private_subnet[local.azs[2]].id,
    #     aws_subnet.std19_private_subnet[local.azs[3]].id
    # ]
    subnet_ids = data.aws_subnets.subnet_ids.ids

    tags = { Name = "std19-db-subnet-group"}
}

# output "choice_subnets" {
#     value = data.aws_subnets.subnet_ids.ids
# }

# =============================================================================
# MySQL Instance 생성
# =============================================================================
resource "aws_db_instance" "std19_mysql_instance" {
    identifier          = "std19-mysql-instance"
    engine              = "mysql"
    engine_version      = "8.0"
    instance_class      = "db.t3.micro" # 연습용, 실제 환경에서 사용x
    allocated_storage   = 20 # 최소사양

    db_name             = "testdb"
    username            = "std19"
    password            = "asdf1234!"
    
    db_subnet_group_name    = aws_db_subnet_group.std19_db_subnet_group.name
    availability_zone       = local.azs[1]
    # vailability_zone      = data.aws_availability_zones.available_az[1].name

    # 보안 그룹
    vpc_security_group_ids= [
        aws_security_group.std19_mysql_sg.id
    ]

    # 백업(최소 7일)
    backup_retention_period = 7
    # instance를 삭제할 때 마지막 백업 스냅샷의 생성 여부
    skip_final_snapshot     = true

    tags = { Name = "std19-mysql-instance"}
}
