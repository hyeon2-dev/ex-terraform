# # ================================================================
# # Amazon Linux 2023 AMI 조회
# # ================================================================

# data "aws_ssm_parameter" "al2023" {
#   name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
# }

# # ================================================================
# # EC2 생성
# # ================================================================

# resource "aws_instance" "this" {
#   ami           = data.aws_ssm_parameter.al2023.value
#   instance_type = "t3.nano"

#   # 부모 main.tf에서 전달받음
#   subnet_id              = var.subnet_id
#   vpc_security_group_ids = var.security_group_ids
#   key_name               = var.key_name

#   # Private 서버 기준
#   associate_public_ip_address = false

#   metadata_options {
#     http_tokens = "required"
#   }

#   # 기본 볼륨: 8 GiB
#   root_block_device {
#     volume_size           = 8
#     volume_type           = "gp3"
#     encrypted             = true
#     delete_on_termination = true

#     tags = {
#       Name = "${var.tag_header}ec2-root"
#     }
#   }

#   # 추가 볼륨: 5 GiB
#   ebs_block_device {
#     device_name           = "/dev/sdf"
#     volume_size           = 5
#     volume_type           = "gp3"
#     encrypted             = true
#     delete_on_termination = true

#     tags = {
#       Name = "${var.tag_header}ec2-data"
#     }
#   }

#   # User Data 변경 시 EC2를 교체해서 다시 실행
#   user_data_replace_on_change = true

#   user_data = <<-EOF
#     #!/bin/bash
#     set -euxo pipefail

#     # 패키지 설치
#     # AL2023 기본 curl-minimal도 curl 명령을 제공함
#     if ! command -v curl >/dev/null 2>&1; then
#       dnf install -y curl-minimal
#     fi

#     dnf install -y docker unzip amazon-efs-utils

#     # Docker 시작 및 부팅 시 자동 실행
#     systemctl enable --now docker

#     # Docker Compose 설치
#     mkdir -p /usr/local/lib/docker/cli-plugins

#     curl -fSL --retry 5 \
#       "https://github.com/docker/compose/releases/download/v5.5.0/docker-compose-linux-x86_64" \
#       -o /usr/local/lib/docker/cli-plugins/docker-compose

#     chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

#     # EFS 마운트 디렉터리
#     mkdir -p /mnt/efs

#     # 재부팅 후에도 자동 마운트
#     echo "${var.efs_id}:/ /mnt/efs efs _netdev,tls 0 0" >> /etc/fstab

#     # DNS 반영 지연 등을 고려해 재시도
#     for attempt in $(seq 1 30); do
#       if mount /mnt/efs; then
#         break
#       fi
#       sleep 10
#     done

#     # 설치 및 마운트 확인
#     docker --version
#     docker compose version
#     mountpoint -q /mnt/efs
#   EOF

#   tags = {
#     Name = "${var.tag_header}ec2"
#   }
# }

# output "instance_id" {
#   value = aws_instance.this.id
# }

# output "private_ip" {
#   value = aws_instance.this.private_ip
# }