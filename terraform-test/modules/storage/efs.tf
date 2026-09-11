# ================================================================
# EFS 보안 그룹
# ================================================================

resource "aws_security_group" "efs_sg" {
  name        = "${var.tag_header}efs-sg"
  description = "Allow NFS from web instances"
  vpc_id      = var.vpc_id

  # 웹 SG가 붙은 EC2 -> EFS
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [ var.web_sg_id ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}efs-sg"
  }
}

# ================================================================
# EFS 파일시스템 1개
# ================================================================

resource "aws_efs_file_system" "this" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "${var.tag_header}efs"
  }
}

# ================================================================
# EFS Mount Target
# Private 서브넷이 AZ당 하나인 현재 구성 기준
# ================================================================

resource "aws_efs_mount_target" "this" {
  for_each = var.private_subnet_ids

  file_system_id = aws_efs_file_system.this.id
  subnet_id      = each.value

  security_groups = [
    aws_security_group.efs_sg.id
  ]
}