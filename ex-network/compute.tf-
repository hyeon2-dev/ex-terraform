# AMI 제작에 사용될 인스턴스 생성
# 이미지 생성 완료후:
# 테라폼 상태에서 제거 : terraform state rm aws_instance.std19_ex_instance
# 
# INSTANCE_ID=$(aws ec2 describe-instances \
# --filters "Name=tag:Name,Values=ian-ex-instance" "Name=instance-state-name,Values=running,stopped" \
# --query "Reservations[*].Instances[*].InstanceId" \
# --output text)
resource "aws_instance" "std19_ex_instance" {

    # ami
    ami                     = "ami-096f5760b00bcd95c"

    # instance_type
    instance_type           = "t3.micro"

    # 키페어, key_name
    key_name                = "std19-key"

    # 볼륨
    root_block_device {
        volume_size         = 20    # 단위 GB
        volume_type         = "gp3" # 볼륨 타입 (최신 가성비 타입인 gp3 권장)
        delete_on_termination   = true  # 인스턴스 종료시 볼륨도 함께 삭제
        tags = {
            Name            = "std19-ex-volume"
        }
    }

    # 서브넷
    subnet_id               = aws_subnet.std19_public_subnet[local.azs[0]].id

    # 보안그룹
    vpc_security_group_ids = [
        aws_security_group.std19_ssh_sg.id,
        aws_security_group.std19_external_alb_sg.id

    ]

    # User Data
    user_data = <<-EOF
        #!/bin/bash
        apt update -y
        apt install -y nginx
        systemctl start nginx
        systemctl enable nginx
        echo "<h1>Hellow from EC2 First Nginx</h2>" > /var/www/html/index.html
        EOF

    tags = {
        Name = "std19-ex-instance"
    }
}

output "instance_public_id" {
    value = aws_instance.std19_ex_instance.public_ip
}

# =========================================================================
# AMI 이미지 생성
# =========================================================================
resource "aws_ami_from_instance" "std19_ex_nginx_ami" {
    name                = "std19-ex-nginx-ami"
    source_instance_id  = aws_instance.std19_ex_instance.id # 대상 인스턴스 ID

    # 재부팅하여 이미지 생성(권장): false
    snapshot_without_reboot = false

    tags = {
        Name ="std19-ex-nginx-ami"
    }
}

# =========================================================================
# 키 페어 생성
# =========================================================================
# resource "aws_key_pair" "std19_lab_key" {
#     key_name = "std19-lab-key"
#     public_key = file("~/.ssh/id_rsa.pub")  #  터미널: ssh-keygen -t rsa -b 4096 -C "std19-instance-key-pair"

#     tags = {
#         Name = "std19-lab-key"
#     }
# }

# =========================================================================
# data {}}을 통한 이미지 선택하여 인스턴스 생성
# =========================================================================

# resource "aws_instance" "std19_ex_ami_instance" {

#     # ami
#     ami                     = data.aws_ami.std19_ex_nginx_ami.id
#     # instance_type
#     instance_type           = "t3.micro"

#     # 키페어, key_name
#     key_name                = "std19-key"

#     # 볼륨
#     root_block_device {
#         volume_size         = 20    # 단위 GB
#         volume_type         = "gp3" # 볼륨 타입 (최신 가성비 타입인 gp3 권장)
#         delete_on_termination   = true  # 인스턴스 종료시 볼륨도 함께 삭제
#         tags = {
#             Name            = "std19-ex-volume"
#         }
#     }

#     # 서브넷
#     subnet_id               = aws_subnet.std19_public_subnet.id

#     # 보안그룹
#     vpc_security_group_ids = [
#         aws_security_group.std19_ssh_sg.id,
#         aws_security_group.std19_external_alb_sg.id

#     ]

#     tags = {
#         Name = "std19-ex-ami-instance"
#     }
# }

# =========================================================================
resource "aws_launch_template" "std19_ex_lt" {
    name_prefix     = "std19-ex-lt-"    # 자동 네이밍을 위해 데쉬로 마무리
    image_id        = local.ami_id
    instance_type   = "t3.nano"

    vpc_security_group_ids = [
        aws_security_group.std19_ssh_sg.id,
        aws_security_group.std19_external_alb_sg.id
    ]

    # 이미 Nginx가 설치되어 있다면 서비스 시작 명령어만 넣어주면 안전합니다.
    # Instance 생성할 때와 달리 base64encode()를 통해 암호화 해야 합니다.
    user_data = base64encode(<<-EOF
        #!/bin/bash
        systemctl start nginx
        systemctl enable nginx
    EOF    
    )

    tag_specifications {
        resource_type = "instance"
        tags = { Name = "std19-ex-asg-instance" }
    }

    tag_specifications {
        resource_type = "volume"
        tags = { Name = "std19-ex-asg-instance-vol" }
    }

    tags = { Name = "std19-ex-asg-lt"}
}
