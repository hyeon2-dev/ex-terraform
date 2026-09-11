output "website_bucket_name" {
  value = aws_s3_bucket.website_bucket.id
}

output "logs_bucket_name" {
  value = aws_s3_bucket.logs_bucket.id
}

output "efs_id" {
  value = aws_efs_file_system.this.id

  # 이 출력을 사용하는 EC2가 마운트 대상 생성도 기다리게 함
  depends_on = [
    aws_efs_mount_target.this
  ]
}

output "efs_dns_name" {
  value = aws_efs_file_system.this.dns_name
}