# provider.tf
# ========================================================================
# 1. 테라폼 실행 환경 설정 블록
# ========================================================================
terraform {
    required_providers {    # 어떤 환경에서 사용할 것인가
        aws = {     # 1
            # provider 라이브러리 다운로드 경로
            source = "hashicorp/aws"

            # 사용할 버전 정의
            version = "~> 5.0"  # 5.0 ~ 6.0 (5.0 이상, 6.0 미만의 최신버전)
        }
    }

    # required_providers {
    #     google = {     # 2
    #         # provider 라이브러리 다운로드 경로
    #         source = "hashicorp/google"

    #         # 사용할 버전 정의
    #         version = "~> 6.0"
    #     }
    # }

   # 협업을 위한 상태 값 공유 저장소 설정
#     backend "s3" {
#         bucket          = "bipa17-student-bucket"                             # 위에서 만든 S3 버킷 이름
#         key             = "TerraformState/Lab/create-vpc/terraform.tfstate"   # 버킷 내 저장 경로
#         region          = "us-west-2"                                         # 리전
#         dynamodb_table  = "std19-terraform-lock-table"                        # DynamoDB 테이블이름
#         encrypt         = true                                                #
#     }
}


provider "aws" {    # 1
    region = "us-west-2"
    default_tags {
        tags = {
            Class = "bipa17"
            Owner = "std19"
        }
    }
}