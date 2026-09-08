# 현재 리전의 가용영역을 문자열 형태의 리스트로 반환
data "aws_availability_zones" "available_az" {
    state           = "available"
}

# AMI 이미지 선택:
# 이미지 생성에 사용된 인스턴스와이미지 생성 코드를 더이상 사용하지
# 않을 경우 AMI를 선택하기위해 추가
data "aws_ami" "std19_ex_nginx_ami" {
    most_recent = true
    owners      = ["self"]  # 본인 AWS 계정에서 생성한 AMI를 검색할 경우 ("self")

    # 1. Name 태그 검색
    filter {
        name    = "tag:Name"
        values  = ["std19-ex-nginx-ami"]
    }

    # # 2. Class 태그 검색
    # filter {
    #     name    = "tag:Class"
    #     values  = ["bipa17"]
    # }

    # # 2. Owner 태그 검색
    # filter {
    #     name    = "tag:Owner"
    #     values  = ["student19"]
    # }
}
