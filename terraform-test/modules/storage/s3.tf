# ================================================================
# 웹사이트용 S3 Bucket
# ================================================================

resource "aws_s3_bucket" "website_bucket" {
  # 뒤에 자동 접미사를 붙여 이름 충돌 방지
  bucket_prefix = "${var.tag_header}website-"

  # 데이터가 있으면 강제로 삭제하지 않음
  force_destroy = false

  tags = {
    Name = "${var.tag_header}website-bucket"
  }
}

# ================================================================
# 로그 보관용 S3 Bucket
# ================================================================

resource "aws_s3_bucket" "logs_bucket" {
  bucket_prefix = "${var.tag_header}logs-"
  force_destroy = false

  tags = {
    Name = "${var.tag_header}logs-bucket"
  }
}

# ================================================================
# 두 버킷의 공통 설정
# ================================================================

locals {
  storage_buckets = {
    website = aws_s3_bucket.website_bucket.id
    logs    = aws_s3_bucket.logs_bucket.id
  }
}

# Public Access 차단
resource "aws_s3_bucket_public_access_block" "website_bucket_access" {
	bucket          = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

# 버전 관리
resource "aws_s3_bucket_versioning" "this" {
  for_each = local.storage_buckets

  bucket = each.value

  versioning_configuration {
    status = "Disabled"
  }
}

# =====================================================================
# 정적 웹사이트 기능 활성화
# =====================================================================
resource "aws_s3_bucket_website_configuration" "this" {
    bucket          = aws_s3_bucket.website_bucket.id
    index_document {
        suffix      = "index.html"
    }
    error_document {
        key         = "error.html"
    }
}


# Public 사용자에게 객체 액세스 권한 부여
resource "aws_s3_bucket_policy" "website_bucket_policy" {
    bucket          = aws_s3_bucket.website_bucket.id
    
    # Bucket Public Access 설정이 우선되어야 함
    depends_on = [
        aws_s3_bucket_public_access_block.website_bucket_access
    ]

    # 정책 생성
    policy = jsonencode({
        Version     = "2012-10-17"
        Statement   = [
            {
                Sid         = "PublicReadGetObject"
                Effect      = "Allow"
                Principal   = "*"
                Action      = "s3:GetObject"
                Resource    = "${aws_s3_bucket.website_bucket.arn}/*"

            }
        ]
    })
}


# # 서버 측 암호화
# resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
#   for_each = local.storage_buckets

#   bucket = each.value

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }
