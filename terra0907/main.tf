resource "aws_s3_bucket" "terraform_state" {
    bucket = "std19-ex-terraform-state-bucket"

    lifecycle {
        prevent_destroy = true  # 삭제 방지
    }

    tags = {
        Name = "std19-ex-terraform-state-bucket"
    }    
}

# 상태 복구를 위한 버전 관리 활성화(상태 복구용)
resource "aws_s3_bucket_versioning" "state_versioning" {
    bucket = aws_s3_bucket.terraform_state.id
    versioning_configuration {
        status = "Enabled"
    }
}

# ========================================================================
# 2. 상태 잠금용 DynamoDB 테이블 생성
# ========================================================================
resource "aws_dynamodb_table" "terraform_lock" {
    name = "std19-lab-lock-table"
    # Dynamodb의 관리 방식(비용과 연관된 설정)
    billing_mode = "PROVISIONED"    # PAY_PER_REQUEST
    hash_key = "LockID"     # 1

    read_capacity = 20      # 초당 4KB 데이터 읽기(RCU) => 1RCU
    write_capacity = 20     # 초당 4KB 데이터 쓰기(WCU) => 1WCU

    attribute {
        name = "LockID"     # 관계형 데이터베이스의 P/K와 같은 역할     1
        type = "S"          # s(String), N(Number), B(Binary)
    }
}