# local.tf
# ======================================================================================
# 로컬 환경 설정 블록
# 정의된 값의 변경없이 사용하는 변수
# ======================================================================================
locals {
    tag_header  = "${var.default_name}-"
    azs         = data.aws_availability_zones.available_az.names
    ami_id      = data.aws_ami.std19_ex_nginx_ami.id
}