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
    subnet_id               = aws_subnet.std19_public_subnet.id

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
resource "aws_key_pair" "std19_lab_key" {
    key_name = "std19-lab-key"
    public_key = file("~/.ssh/id_rsa.pub")  #  터미널: ssh-keygen -t rsa -b 4096 -C "std19-instance-key-pair"

    tags = {
        Name = "std19-lab-key"
    }
}

